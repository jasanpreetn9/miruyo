import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
	anilistQuery,
	AniListError,
	cachedQuery,
	CACHE_TTL,
	clearCache,
	fetchCustomLists,
	fetchListCollection,
	fetchUserList,
	isPrivateUser,
	onRefreshed,
	onUnauthorized,
	requestStamp,
	saveEntry,
	updateViewerSettings,
	useEditClock
} from './client.ts';

function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}) {
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json', ...headers }
	});
}

const fetchMock = vi.fn();

beforeEach(() => {
	clearCache();
	fetchMock.mockReset();
	vi.stubGlobal('fetch', fetchMock);
});

afterEach(() => {
	vi.useRealTimers();
	vi.unstubAllGlobals();
	onUnauthorized(null);
});

async function caught(promise: Promise<unknown>): Promise<AniListError> {
	try {
		await promise;
	} catch (err) {
		if (err instanceof AniListError) return err;
		throw err;
	}
	throw new Error('expected the request to fail');
}

describe('anilistQuery errors', () => {
	it('reports a 429 as a rate limit with the Retry-After delay', async () => {
		fetchMock.mockResolvedValue(
			jsonResponse({ errors: [{ message: 'Too Many Requests.' }] }, 429, { 'Retry-After': '12' })
		);
		const err = await caught(anilistQuery('query A {}'));
		expect(err).toMatchObject({ kind: 'rate-limit', retryAfter: 12 });
	});

	it('falls back to a minute when a 429 has no delay header', async () => {
		fetchMock.mockResolvedValue(jsonResponse({}, 429));
		expect((await caught(anilistQuery('query A {}'))).retryAfter).toBe(60);
	});

	it('reports a rejected token as unauthorized and tells the session', async () => {
		const handler = vi.fn();
		onUnauthorized(handler);
		fetchMock.mockResolvedValue(
			jsonResponse({ errors: [{ message: 'Invalid token', status: 400 }] }, 400)
		);
		const err = await caught(anilistQuery('query A {}', {}, 'stale-token'));
		expect(err.kind).toBe('unauthorized');
		expect(handler).toHaveBeenCalledOnce();
	});

	it("doesn't sign out over a permission error that isn't about the token", async () => {
		const handler = vi.fn();
		onUnauthorized(handler);
		fetchMock.mockResolvedValue(
			jsonResponse({ errors: [{ message: 'Unauthorized.', status: 400 }] }, 400)
		);
		const err = await caught(anilistQuery('query A {}', {}, 'good-token'));
		expect(err.kind).toBe('api');
		expect(handler).not.toHaveBeenCalled();
	});

	it("doesn't treat a 401 on a token-less request as a sign-out", async () => {
		const handler = vi.fn();
		onUnauthorized(handler);
		fetchMock.mockResolvedValue(jsonResponse({ errors: [{ message: 'Unauthorized.' }] }, 401));
		expect((await caught(anilistQuery('query A {}', {}, null))).kind).toBe('api');
		expect(handler).not.toHaveBeenCalled();
	});

	it('keeps AniList validation messages', async () => {
		fetchMock.mockResolvedValue(jsonResponse({ errors: [{ message: 'Bad field' }] }, 400));
		const err = await caught(anilistQuery('query A {}'));
		expect(err).toMatchObject({ kind: 'api', status: 400, message: 'Bad field' });
	});

	// AniList's 429 has no CORS headers, so the browser reports it as a failed fetch
	it('reports a failed fetch while online as a rate limit, waiting a minute', async () => {
		vi.stubGlobal('navigator', { onLine: true });
		fetchMock.mockRejectedValue(new TypeError('Failed to fetch'));
		expect(await caught(anilistQuery('query A {}'))).toMatchObject({
			kind: 'rate-limit',
			retryAfter: 60
		});
	});

	it('reports a failed fetch while offline as a network error', async () => {
		vi.stubGlobal('navigator', { onLine: false });
		fetchMock.mockRejectedValue(new TypeError('Failed to fetch'));
		expect((await caught(anilistQuery('query A {}'))).kind).toBe('network');
	});

	it('sends no Authorization header when the token is null', async () => {
		fetchMock.mockResolvedValue(jsonResponse({ data: {} }));
		await anilistQuery('query A {}', {}, null);
		const init = fetchMock.mock.calls[0][1] as RequestInit;
		expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
	});
});

describe('cachedQuery', () => {
	it('merges identical requests that are in flight together', async () => {
		fetchMock.mockResolvedValue(jsonResponse({ data: { n: 1 } }));
		const [a, b] = await Promise.all([
			cachedQuery('query A {}', { x: 1 }),
			cachedQuery('query A {}', { x: 1 })
		]);
		expect(a).toEqual({ n: 1 });
		expect(b).toBe(a);
		expect(fetchMock).toHaveBeenCalledOnce();
	});

	it('keys on variables and token', async () => {
		fetchMock.mockImplementation(async () => jsonResponse({ data: {} }));
		await cachedQuery('query A {}', { x: 1 });
		await cachedQuery('query A {}', { x: 2 });
		await cachedQuery('query A {}', { x: 1 }, { authToken: 'someone-else' });
		expect(fetchMock).toHaveBeenCalledTimes(3);
	});

	it('reuses a result until it expires', async () => {
		vi.useFakeTimers();
		fetchMock.mockImplementation(async () => jsonResponse({ data: {} }));
		await cachedQuery('query A {}');
		await cachedQuery('query A {}');
		expect(fetchMock).toHaveBeenCalledOnce();
		vi.advanceTimersByTime(CACHE_TTL + 1);
		await cachedQuery('query A {}');
		expect(fetchMock).toHaveBeenCalledTimes(2);
	});

	it("doesn't cache failures", async () => {
		fetchMock
			.mockResolvedValueOnce(jsonResponse({}, 500))
			.mockResolvedValueOnce(jsonResponse({ data: { ok: true } }));
		await expect(cachedQuery('query A {}')).rejects.toThrow();
		await expect(cachedQuery('query A {}')).resolves.toEqual({ ok: true });
	});

	it('drops viewer responses after a successful save', async () => {
		fetchMock.mockImplementation(async (_url: string, init: RequestInit) => {
			const { query } = JSON.parse(init.body as string);
			return jsonResponse({
				data: query.includes('SaveEntry') ? { SaveMediaListEntry: { id: 1 } } : {}
			});
		});
		await cachedQuery('query A {}', {}, { authToken: 'tok' });
		await saveEntry(5, { progress: 3, notes: undefined });
		await cachedQuery('query A {}', {}, { authToken: 'tok' });
		expect(fetchMock).toHaveBeenCalledTimes(3);

		const saveBody = JSON.parse((fetchMock.mock.calls[1][1] as RequestInit).body as string);
		expect(saveBody.variables).toEqual({ mediaId: 5, progress: 3 });
	});

	it('keeps public responses cached across a save', async () => {
		fetchMock.mockImplementation(async (_url: string, init: RequestInit) => {
			const { query } = JSON.parse(init.body as string);
			return jsonResponse({
				data: query.includes('SaveEntry') ? { SaveMediaListEntry: { id: 1 } } : {}
			});
		});
		await cachedQuery('query Public {}', {}, { authToken: null });
		await cachedQuery('query Viewer {}', {}, { authToken: 'tok' });
		await saveEntry(5, { progress: 3 });
		await cachedQuery('query Public {}', {}, { authToken: null });
		await cachedQuery('query Viewer {}', {}, { authToken: 'tok' });
		// public 1 + viewer 2 + save 1
		expect(fetchMock).toHaveBeenCalledTimes(4);
	});
});

describe('stale-while-revalidate', () => {
	const SWR = { authToken: 'tok', staleWhileRevalidate: true } as const;
	/** A local edit clock, as the list store's stamp(). */
	let clock = 0;
	let version = 0;
	/** Each read answers with the call's number, so copies tell apart. */
	function answerInOrder() {
		version = 0;
		fetchMock.mockImplementation(async (_url: string, init: RequestInit) => {
			const { query } = JSON.parse(init.body as string);
			if (query.includes('SaveEntry')) {
				clock++;
				return jsonResponse({ data: { SaveMediaListEntry: { id: 1 } } });
			}
			return jsonResponse({ data: { v: ++version } });
		});
	}
	const settle = () => new Promise((r) => setTimeout(r, 0));
	const reads = () =>
		fetchMock.mock.calls.filter(
			([, init]) => !(init as RequestInit).body!.toString().includes('SaveEntry')
		).length;

	beforeEach(() => {
		clock = 0;
		useEditClock(() => clock);
		answerInOrder();
	});
	afterEach(() => useEditClock(() => 0));

	it('serves an expired list at once and swaps in the newer copy behind it', async () => {
		vi.useFakeTimers();
		let refreshed = 0;
		const stop = onRefreshed(() => refreshed++);
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 1 });
		vi.advanceTimersByTime(CACHE_TTL + 1);
		// stale, at once; one refresh however many read it
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 1 });
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 1 });
		await vi.advanceTimersByTimeAsync(0);
		expect(reads()).toBe(2);
		expect(refreshed).toBe(1);
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 2 });
		stop();
	});

	it("keeps a list after a save, but says it's older than the edit", async () => {
		const before = await cachedQuery<object>('query L {}', {}, SWR);
		expect(requestStamp(before)).toBe(0);
		await saveEntry(5, { progress: 3 });
		// the copy from before the edit comes back at once, marked as older
		const stale = await cachedQuery<object>('query L {}', {}, SWR);
		expect(stale).toBe(before);
		expect(requestStamp(stale)).toBeLessThan(clock);
		await settle();
		const after = await cachedQuery<object>('query L {}', {}, SWR);
		expect(after).toEqual({ v: 2 });
		expect(requestStamp(after)).toBe(clock);
	});

	it('a copy requested before an edit stays stale, even once it arrives', async () => {
		let release!: () => void;
		fetchMock.mockImplementationOnce(
			() => new Promise((r) => (release = () => r(jsonResponse({ data: { v: 1 } }))))
		);
		const first = cachedQuery<object>('query L {}', {}, SWR);
		await saveEntry(5, { progress: 3 });
		release();
		expect(requestStamp(await first)).toBeLessThan(clock);
		// so the next read loads another
		await cachedQuery('query L {}', {}, SWR);
		await settle();
		expect(reads()).toBe(2);
	});

	it('waits for the network when asked for a fresh copy', async () => {
		vi.useFakeTimers();
		await cachedQuery('query L {}', {}, SWR);
		vi.advanceTimersByTime(CACHE_TTL + 1);
		expect(await cachedQuery('query L {}', {}, { ...SWR, fresh: true })).toEqual({ v: 2 });
	});

	it('keeps the stale copy when the refresh fails, and tries again next time', async () => {
		vi.useFakeTimers();
		await cachedQuery('query L {}', {}, SWR);
		vi.advanceTimersByTime(CACHE_TTL + 1);
		fetchMock.mockResolvedValueOnce(jsonResponse({}, 500));
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 1 });
		await vi.advanceTimersByTimeAsync(0);
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 1 });
		await vi.advanceTimersByTimeAsync(0);
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 2 });
	});

	it('drops it after a settings save: a new score format changes every score', async () => {
		const before = await cachedQuery<object>('query L {}', {}, SWR);
		await updateViewerSettings({ scoreFormat: 'POINT_100' });
		const after = await cachedQuery<object>('query L {}', {}, SWR);
		// a new request, waited for: not the copy in the old format
		expect(after).not.toBe(before);
		expect(reads()).toBe(3);
	});

	it('forgets it on sign-out, refresh or not', async () => {
		vi.useFakeTimers();
		await cachedQuery('query L {}', {}, SWR);
		vi.advanceTimersByTime(CACHE_TTL + 1);
		void cachedQuery('query L {}', {}, SWR);
		clearCache();
		await vi.advanceTimersByTimeAsync(0);
		// the refresh that landed after the sign-out didn't bring it back
		expect(await cachedQuery('query L {}', {}, SWR)).toEqual({ v: 3 });
	});
});

describe('updateViewerSettings', () => {
	it('sends only the settings being changed and returns what AniList saved', async () => {
		fetchMock.mockResolvedValue(
			jsonResponse({
				data: {
					UpdateUser: {
						id: 1,
						options: { titleLanguage: 'ENGLISH', displayAdultContent: false },
						mediaListOptions: { scoreFormat: 'POINT_10' }
					}
				}
			})
		);
		const saved = await updateViewerSettings({
			titleLanguage: 'ENGLISH',
			displayAdultContent: undefined
		});
		const body = JSON.parse((fetchMock.mock.calls[0][1] as RequestInit).body as string);
		expect(body.query).toContain('mutation UpdateSettings');
		expect(body.variables).toEqual({ titleLanguage: 'ENGLISH' });
		expect(saved.options).toEqual({ titleLanguage: 'ENGLISH', displayAdultContent: false });
		expect(saved.mediaListOptions).toEqual({ scoreFormat: 'POINT_10' });
	});
});

describe('custom lists', () => {
	const entry = (mediaId: number) => ({ mediaId, media: { id: mediaId } });
	const collection = {
		data: {
			MediaListCollection: {
				lists: [
					{ name: 'Rewatch', status: null, isCustomList: true, entries: [entry(1), entry(3)] },
					{ name: 'Completed', status: 'COMPLETED', isCustomList: false, entries: [entry(1)] },
					{ name: 'Empty', status: null, isCustomList: true, entries: [] }
				]
			}
		}
	};

	it('keeps titles that are only on a custom list, once each', async () => {
		fetchMock.mockResolvedValue(jsonResponse(collection));
		const entries = await fetchListCollection(9, 'ANIME');
		expect(entries.map((e) => e.mediaId)).toEqual([1, 3]);
	});

	it('reads a missing collection as an empty list', async () => {
		fetchMock.mockResolvedValue(jsonResponse({ data: { MediaListCollection: null } }));
		expect(await fetchListCollection(9, 'ANIME')).toEqual([]);
		expect(await fetchCustomLists(9, 'ANIME')).toEqual({ lists: [], hidden: [] });
		fetchMock.mockResolvedValue(jsonResponse({ data: { MediaListCollection: { lists: null } } }));
		expect(await fetchUserList(9, 'MANGA')).toEqual([]);
	});

	it('names each custom list, and the titles hidden from status lists, from the same request', async () => {
		fetchMock.mockResolvedValue(jsonResponse(collection));
		await fetchListCollection(9, 'ANIME');
		expect(await fetchCustomLists(9, 'ANIME')).toEqual({
			lists: [{ name: 'Rewatch', mediaIds: [1, 3] }],
			hidden: [3]
		});
		expect(fetchMock).toHaveBeenCalledTimes(1);
	});
});

describe('fetchUserList', () => {
	const entry = (mediaId: number, status: string) => ({
		id: mediaId * 10,
		mediaId,
		status,
		progress: 1,
		progressVolumes: null,
		score: 8.5,
		repeat: 0,
		updatedAt: 0,
		startedAt: { year: null, month: null, day: null },
		completedAt: { year: null, month: null, day: null },
		media: { id: mediaId }
	});

	it('asks for scores out of 10 without a token, each title once', async () => {
		fetchMock.mockResolvedValue(
			jsonResponse({
				data: {
					MediaListCollection: {
						lists: [
							{ isCustomList: false, entries: [entry(1, 'COMPLETED'), entry(2, 'COMPLETED')] },
							{ isCustomList: true, entries: [entry(1, 'COMPLETED'), entry(4, 'PAUSED')] },
							{ isCustomList: false, entries: [entry(3, 'CURRENT')] }
						]
					}
				}
			})
		);
		const entries = await fetchUserList(2, 'ANIME');
		// 4 is only on a custom list ("hide from status lists"): kept, after the status lists
		expect(entries.map((e) => e.mediaId)).toEqual([1, 2, 3, 4]);
		expect(entries[0]).toMatchObject({ score: 8.5, notes: null, private: false });
		const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
		expect(new Headers(init.headers).has('Authorization')).toBe(false);
		expect(JSON.parse(init.body as string).query).toContain('score(format: POINT_10_DECIMAL)');
	});

	it('tells a private user apart from other failures', async () => {
		fetchMock.mockResolvedValue(
			jsonResponse({ errors: [{ message: 'Private User', status: 404 }], data: null }, 404)
		);
		expect(isPrivateUser(await caught(fetchUserList(1, 'ANIME')))).toBe(true);
		fetchMock.mockResolvedValue(
			jsonResponse({ errors: [{ message: 'Not Found.', status: 404 }], data: null }, 404)
		);
		expect(isPrivateUser(await caught(fetchUserList(99, 'ANIME')))).toBe(false);
	});
});
