import { afterEach, describe, expect, it, vi } from 'vitest';
import { AniListError } from '#lib/anilist/client.ts';
import { Resource } from './resource.svelte.ts';

function deferred<T>() {
	let resolve!: (v: T) => void;
	let reject!: (e: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
}

afterEach(() => {
	vi.useRealTimers();
	vi.restoreAllMocks();
});

describe('Resource', () => {
	it('loads data and reports pending until it arrives', async () => {
		const r = new Resource<string>();
		const d = deferred<string>();
		const loading = r.load('a', () => d.promise);
		expect(r.pending).toBe(true);
		d.resolve('data');
		await loading;
		expect(r.data).toBe('data');
		expect(r.pending).toBe(false);
		expect(r.failed).toBe(false);
	});

	it('drops a response that a newer load superseded', async () => {
		const r = new Resource<string>();
		const slow = deferred<string>();
		const first = r.load('a', () => slow.promise);
		await r.load('a', async () => 'newer');
		slow.resolve('stale');
		await first;
		expect(r.data).toBe('newer');
	});

	it('keeps the last good data when a reload of the same key fails', async () => {
		vi.spyOn(console, 'error').mockImplementation(() => {});
		const r = new Resource<string>();
		await r.load('a', async () => 'cached');
		await r.load('a', async () => {
			throw new Error('down');
		});
		expect(r.data).toBe('cached');
		expect(r.error).toBe('down');
		expect(r.failed).toBe(false);
	});

	it('clears data when the key changes, so another mode never shows', async () => {
		vi.spyOn(console, 'error').mockImplementation(() => {});
		const r = new Resource<string>();
		await r.load('user:anime', async () => 'anime rows');
		await r.load('user:manga', async () => {
			throw new Error('down');
		});
		expect(r.data).toBeNull();
		expect(r.failed).toBe(true);
	});

	it('retries a rate limit on its own after the countdown', async () => {
		vi.useFakeTimers();
		vi.spyOn(console, 'error').mockImplementation(() => {});
		const r = new Resource<string>();
		const fetch = vi
			.fn()
			.mockRejectedValueOnce(new AniListError('slow down', 'rate-limit', 429, 3))
			.mockResolvedValueOnce('data');
		const onData = vi.fn();
		await r.load('a', fetch, onData);
		expect(r.rateLimited).toBe(true);
		expect(r.retry.label).toBe('0:03');

		await vi.advanceTimersByTimeAsync(3000);
		expect(fetch).toHaveBeenCalledTimes(2);
		expect(r.data).toBe('data');
		expect(r.rateLimited).toBe(false);
		expect(onData).toHaveBeenCalledWith('data');
	});

	it('reset() forgets everything and ignores a load still in flight', async () => {
		const r = new Resource<string>();
		const slow = deferred<string>();
		const loading = r.load('a', () => slow.promise);
		r.reset();
		slow.resolve('late');
		await loading;
		expect(r.data).toBeNull();
		expect(r.loading).toBe(false);
	});
});
