import { isAniListError } from '#lib/anilist/client.ts';
import { RetryCountdown } from './countdown.svelte.ts';

/**
 * One independently loaded piece of a page (e.g. Home's list vs. its rows),
 * so a failure only takes down its own section:
 *
 * - A newer load() supersedes an older one; late responses are dropped.
 * - Changing `key` (user or mode) clears the old data, so a section never
 *   shows another mode's results under the new headings.
 * - A failure on the same key keeps the last good data — cached rows stay
 *   usable — and a 429 retries on its own after the countdown.
 */
export class Resource<T> {
	data = $state<T | null>(null);
	loading = $state(false);
	/** The last failure's message; '' when the last load succeeded. */
	error = $state('');
	rateLimited = $state(false);
	readonly retry = new RetryCountdown();

	#key = '';
	#latest = 0;

	/** True while there's nothing to show yet (first load, or after a key change). */
	get pending(): boolean {
		return this.loading && this.data === null;
	}

	/** True when the section has nothing to show because loading failed. */
	get failed(): boolean {
		return !!this.error && this.data === null;
	}

	async load(key: string, fetch: () => Promise<T>, onData?: (data: T) => void): Promise<void> {
		this.retry.stop();
		const request = ++this.#latest;
		if (key !== this.#key) {
			this.data = null;
			this.#key = key;
		}
		this.loading = true;
		try {
			const data = await fetch();
			if (request !== this.#latest) return;
			this.data = data;
			this.error = '';
			this.rateLimited = false;
			onData?.(data);
		} catch (err) {
			if (request !== this.#latest) return;
			console.error(`Failed to load ${key}:`, err);
			this.error = err instanceof Error ? err.message : String(err);
			this.rateLimited = isAniListError(err, 'rate-limit');
			if (isAniListError(err, 'rate-limit')) {
				this.retry.start(err.retryAfter ?? 60, () => this.load(key, fetch, onData));
			}
		} finally {
			if (request === this.#latest) this.loading = false;
		}
	}

	/** Forget everything (sign-out, unmount). */
	reset(): void {
		this.retry.stop();
		this.#latest++;
		this.#key = '';
		this.data = null;
		this.loading = false;
		this.error = '';
		this.rateLimited = false;
	}
}
