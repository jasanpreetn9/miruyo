// Keeps a tab under AniList's rate limit instead of running into it.
//
// AniList allows a set number of requests a minute (90, or 30 when it's
// busy) and every response says how many are left (X-RateLimit-Limit /
// X-RateLimit-Remaining). While plenty are left, requests go straight out.
// When few are, they go out one at a time at the limit's own pace (one
// every two seconds at 30 a minute), so a busy page loads a little slower
// instead of hitting a 429. And when a 429 does say how long to wait
// (Retry-After), every request waits that out rather than each failing on
// its own.

/** At or below this many left, requests are spaced out. */
export const LOW_WATER = 5;
/** What AniList reports is only trusted this long: its window is a minute. */
const STALE_AFTER = 60_000;

/** Where the last count is kept between page loads (sessionStorage in the browser). */
export interface PaceStore {
	getItem(key: string): string | null;
	setItem(key: string, value: string): void;
}

export class Pacer {
	#limit = 90;
	/** What the last response said was left, or Infinity when unknown. */
	#remaining = Infinity;
	#seenAt = 0;
	/** Sent since the last response, so not counted in #remaining yet. */
	#inFlight = 0;
	/** When the next spaced-out request may go. */
	#next = 0;
	#pausedUntil = 0;

	constructor(
		readonly now: () => number = Date.now,
		readonly sleep: (ms: number) => Promise<void> = (ms) =>
			new Promise((resolve) => setTimeout(resolve, ms)),
		/** With a store, a reload (or a hot reload) starts from the last count, not from nothing. */
		readonly store: { storage: PaceStore; key: string } | null = null
	) {
		try {
			const saved = JSON.parse(store?.storage.getItem(store.key) ?? 'null') as {
				limit: number;
				remaining: number;
				seenAt: number;
			} | null;
			if (saved && saved.limit > 0 && Number.isFinite(saved.remaining)) {
				this.#limit = saved.limit;
				this.#remaining = saved.remaining;
				this.#seenAt = saved.seenAt;
			}
		} catch {
			// nothing saved, or storage is off: start fresh
		}
	}

	#save(): void {
		try {
			this.store?.storage.setItem(
				this.store.key,
				JSON.stringify({ limit: this.#limit, remaining: this.#remaining, seenAt: this.#seenAt })
			);
		} catch {
			// storage full or off: the count just isn't remembered
		}
	}

	/** How many are likely left right now. */
	get left(): number {
		if (this.now() - this.#seenAt > STALE_AFTER) return Infinity;
		return this.#remaining - this.#inFlight;
	}

	/** The gap between requests at the limit's pace, in ms. */
	get spacing(): number {
		return Math.ceil(60_000 / this.#limit);
	}

	/** Resolves when a request may go out; call it right before sending. */
	async slot(): Promise<void> {
		for (;;) {
			const low = this.left <= LOW_WATER;
			const wait = Math.max(this.#pausedUntil, low ? this.#next : 0) - this.now();
			if (wait <= 0) break;
			await this.sleep(wait);
		}
		// no await between the check and these: the next caller sees them
		if (this.left <= LOW_WATER) this.#next = Math.max(this.now(), this.#next) + this.spacing;
		this.#inFlight++;
	}

	/** Reads AniList's headers off a response (any status). */
	settle(headers: Pick<Headers, 'get'> | null): void {
		this.#inFlight = Math.max(0, this.#inFlight - 1);
		const limit = Number(headers?.get('X-RateLimit-Limit'));
		const remaining = Number(headers?.get('X-RateLimit-Remaining'));
		if (limit > 0) this.#limit = limit;
		if (headers?.get('X-RateLimit-Remaining') !== null && Number.isFinite(remaining)) {
			this.#remaining = remaining;
			this.#seenAt = this.now();
			this.#save();
		}
	}

	/**
	 * A request got no response while online: in the browser that's how a 429
	 * looks (it carries no CORS headers, so nothing can be read). Take it as
	 * nothing left, so what follows goes out one at a time.
	 */
	limited(): void {
		this.#remaining = 0;
		this.#seenAt = this.now();
		this.#save();
	}

	/** A 429 said to wait this many seconds: everything waits. */
	pause(seconds: number): void {
		this.#pausedUntil = Math.max(this.#pausedUntil, this.now() + seconds * 1000);
	}
}
