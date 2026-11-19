import { isAniListError } from '#lib/anilist/client.ts';
import { RetryCountdown } from './countdown.svelte.ts';

export interface Page<T> {
	items: T[];
	/** null when the API doesn't say. */
	total: number | null;
	hasMore: boolean;
}

/**
 * A paginated list (Browse results):
 *
 * - load(key) starts over for a new query; the same key is a no-op unless forced.
 * - While a new query loads, the previous results stay on screen (`stale`),
 *   so typing doesn't flash the grid empty.
 * - A newer load supersedes older ones and in-flight "load more"s.
 * - A 429 retries the failed request on its own after the countdown.
 */
export class PagedResults<T> {
	items = $state<T[]>([]);
	total = $state<number | null>(null);
	hasMore = $state(false);
	/** Loading the first page of the current key. */
	loading = $state(false);
	loadingMore = $state(false);
	/** The last failure's message; '' when the last request succeeded. */
	error = $state('');
	rateLimited = $state(false);
	readonly retry = new RetryCountdown();

	#key: string | null = null;
	/** The key `items` belong to. */
	#itemsKey: string | null = null;
	#page = 0;
	#latest = 0;
	#fetch: ((page: number) => Promise<Page<T>>) | null = null;
	#onItems: ((items: T[]) => void) | undefined;

	/** Results from a previous query, shown while the current one loads. */
	get stale(): boolean {
		return this.loading && this.#itemsKey !== this.#key;
	}

	/** Nothing to show yet. */
	get pending(): boolean {
		return this.loading && this.items.length === 0;
	}

	/** The current query has failed and there's nothing of its own to show. */
	get failed(): boolean {
		return !!this.error && !this.loading && this.#itemsKey !== this.#key;
	}

	load(
		key: string,
		fetchPage: (page: number) => Promise<Page<T>>,
		{ force = false, onItems }: { force?: boolean; onItems?: (items: T[]) => void } = {}
	): Promise<void> {
		if (!force && key === this.#key && (this.loading || this.#itemsKey === key)) {
			return Promise.resolve();
		}
		this.#key = key;
		this.#fetch = fetchPage;
		this.#onItems = onItems;
		return this.#request(1);
	}

	loadMore(): Promise<void> {
		if (!this.hasMore || this.loading || this.loadingMore || !this.#fetch) return Promise.resolve();
		return this.#request(this.#page + 1);
	}

	/** Re-runs whatever failed last (first page or the next page). */
	retryNow(): Promise<void> {
		if (!this.#fetch || this.#key === null) return Promise.resolve();
		return this.#request(this.#itemsKey === this.#key ? this.#page + 1 : 1);
	}

	async #request(page: number): Promise<void> {
		this.retry.stop();
		const request = ++this.#latest;
		const key = this.#key;
		const fetchPage = this.#fetch!;
		if (page === 1) this.loading = true;
		else this.loadingMore = true;
		try {
			const result = await fetchPage(page);
			if (request !== this.#latest) return;
			this.items = page === 1 ? result.items : [...this.items, ...result.items];
			this.total = result.total;
			this.hasMore = result.hasMore;
			this.#page = page;
			this.#itemsKey = key;
			this.error = '';
			this.rateLimited = false;
			this.#onItems?.(result.items);
		} catch (err) {
			if (request !== this.#latest) return;
			console.error(`Failed to load page ${page} of ${key}:`, err);
			this.error = err instanceof Error ? err.message : String(err);
			this.rateLimited = isAniListError(err, 'rate-limit');
			if (isAniListError(err, 'rate-limit')) {
				this.retry.start(err.retryAfter ?? 60, () => void this.#request(page));
			}
		} finally {
			if (request === this.#latest) {
				this.loading = false;
				this.loadingMore = false;
			}
		}
	}

	reset(): void {
		this.retry.stop();
		this.#latest++;
		this.#key = null;
		this.#itemsKey = null;
		this.#page = 0;
		this.items = [];
		this.total = null;
		this.hasMore = false;
		this.loading = false;
		this.loadingMore = false;
		this.error = '';
		this.rateLimited = false;
	}
}
