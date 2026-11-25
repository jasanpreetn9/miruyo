import { afterEach, describe, expect, it, vi } from 'vitest';
import type { RequestEvent } from '@sveltejs/kit';
import { handle } from './hooks.server.ts';

// Workers' edge cache, stood in for by a Map keyed on the URL
function stubCache() {
	const stored = new Map<string, Response>();
	vi.stubGlobal('caches', {
		default: {
			match: async (req: Request) => stored.get(req.url)?.clone(),
			put: async (req: Request, res: Response) => void stored.set(req.url, res)
		}
	});
	return stored;
}

function run(url: string, cacheControl: string | null, method = 'GET') {
	const resolve = vi.fn(
		async () =>
			new Response('page', { headers: cacheControl ? { 'cache-control': cacheControl } : {} })
	);
	const event = { request: new Request(url, { method }), url: new URL(url) } as RequestEvent;
	return { resolve, response: handle({ event, resolve }) };
}

describe('the edge cache', () => {
	afterEach(() => vi.unstubAllGlobals());

	it('keeps public pages and serves them from the cache', async () => {
		const stored = stubCache();
		const cc = 'public, max-age=0, s-maxage=600, stale-while-revalidate=86400';
		const first = run('https://miruyo.test/seasonal', cc);
		expect(await (await first.response).text()).toBe('page');
		expect(stored.has('https://miruyo.test/seasonal')).toBe(true);

		const second = run('https://miruyo.test/seasonal', cc);
		expect(await (await second.response).text()).toBe('page');
		expect(second.resolve).not.toHaveBeenCalled();
	});

	it('leaves personal pages, and anything but GET, alone', async () => {
		const stored = stubCache();
		await run('https://miruyo.test/list', null).response;
		await run('https://miruyo.test/list', 'private, max-age=0').response;
		await run('https://miruyo.test/seasonal', 'public, s-maxage=600', 'POST').response;
		expect(stored.size).toBe(0);
	});

	it('does nothing without a cache (dev, tests)', async () => {
		const { resolve, response } = run('https://miruyo.test/seasonal', 'public, s-maxage=600');
		expect((await response).status).toBe(200);
		expect(resolve).toHaveBeenCalledOnce();
	});
});
