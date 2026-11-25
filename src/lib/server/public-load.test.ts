import { describe, expect, it, vi } from 'vitest';
import { DATA_REQUEST_CACHE, loadPublic } from './public-load.ts';

describe('loadPublic', () => {
	it("answers a navigation's data request with null, cached, without fetching", async () => {
		const setHeaders = vi.fn();
		const fetch = vi.fn(async () => 'data');
		expect(await loadPublic({ isDataRequest: true, setHeaders }, fetch)).toBeNull();
		expect(fetch).not.toHaveBeenCalled();
		expect(setHeaders).toHaveBeenCalledWith({ 'cache-control': DATA_REQUEST_CACHE });
	});
});
