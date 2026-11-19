import { afterEach, describe, expect, it, vi } from 'vitest';
import { AniListError } from '#lib/anilist/client.ts';
import { PagedResults, type Page } from './paged.svelte.ts';

function deferred<T>() {
	let resolve!: (v: T) => void;
	let reject!: (e: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
}

const page = (items: number[], hasMore = false, total: number | null = 99): Page<number> => ({
	items,
	hasMore,
	total
});

afterEach(() => {
	vi.useRealTimers();
	vi.restoreAllMocks();
});

describe('PagedResults', () => {
	it('loads the first page, then appends more', async () => {
		const r = new PagedResults<number>();
		const fetch = vi
			.fn()
			.mockResolvedValueOnce(page([1, 2], true))
			.mockResolvedValueOnce(page([3], false));
		await r.load('q', fetch);
		expect(r.items).toEqual([1, 2]);
		expect(r.hasMore).toBe(true);
		await r.loadMore();
		expect(fetch).toHaveBeenLastCalledWith(2);
		expect(r.items).toEqual([1, 2, 3]);
		expect(r.hasMore).toBe(false);
		await r.loadMore(); // nothing more
		expect(fetch).toHaveBeenCalledTimes(2);
	});

	it('does nothing for the same key unless forced', async () => {
		const r = new PagedResults<number>();
		const fetch = vi.fn().mockResolvedValue(page([1]));
		await r.load('q', fetch);
		await r.load('q', fetch);
		expect(fetch).toHaveBeenCalledTimes(1);
		await r.load('q', fetch, { force: true });
		expect(fetch).toHaveBeenCalledTimes(2);
	});

	it('keeps the previous results on screen while a new query loads', async () => {
		const r = new PagedResults<number>();
		await r.load('a', async () => page([1, 2]));
		const next = deferred<Page<number>>();
		const loading = r.load('b', () => next.promise);
		expect(r.stale).toBe(true);
		expect(r.pending).toBe(false);
		expect(r.items).toEqual([1, 2]);
		next.resolve(page([9]));
		await loading;
		expect(r.stale).toBe(false);
		expect(r.items).toEqual([9]);
	});

	it('drops a response that a newer query superseded', async () => {
		const r = new PagedResults<number>();
		const slow = deferred<Page<number>>();
		const first = r.load('a', () => slow.promise);
		await r.load('b', async () => page([2]));
		slow.resolve(page([1]));
		await first;
		expect(r.items).toEqual([2]);
	});

	it('reports a failed query, and keeps loaded pages when "more" fails', async () => {
		vi.spyOn(console, 'error').mockImplementation(() => {});
		const r = new PagedResults<number>();
		await r.load('a', async () => {
			throw new Error('down');
		});
		expect(r.failed).toBe(true);
		expect(r.error).toBe('down');

		const fetch = vi
			.fn()
			.mockResolvedValueOnce(page([1], true))
			.mockRejectedValueOnce(new Error('more failed'))
			.mockResolvedValueOnce(page([2]));
		await r.load('b', fetch);
		await r.loadMore();
		expect(r.items).toEqual([1]);
		expect(r.failed).toBe(false);
		expect(r.error).toBe('more failed');
		await r.retryNow();
		expect(fetch).toHaveBeenLastCalledWith(2);
		expect(r.items).toEqual([1, 2]);
	});

	it('retries a rate limit on its own', async () => {
		vi.useFakeTimers();
		vi.spyOn(console, 'error').mockImplementation(() => {});
		const r = new PagedResults<number>();
		const fetch = vi
			.fn()
			.mockRejectedValueOnce(new AniListError('slow down', 'rate-limit', 429, 2))
			.mockResolvedValueOnce(page([1]));
		await r.load('a', fetch);
		expect(r.rateLimited).toBe(true);
		await vi.advanceTimersByTimeAsync(2000);
		expect(r.items).toEqual([1]);
		expect(r.rateLimited).toBe(false);
	});

	it('hands each page to onItems', async () => {
		const r = new PagedResults<number>();
		const onItems = vi.fn();
		await r.load('a', async (p) => page([p * 10], p < 2), { onItems });
		await r.loadMore();
		expect(onItems.mock.calls).toEqual([[[10]], [[20]]]);
	});
});
