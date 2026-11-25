import { test, expect, type Page } from '@playwright/test';

// Does the production build start? Every page must hydrate without an
// uncaught error, on a first load and after a client-side navigation, served
// by the Worker itself (Cloudflare's runtime, through `vite preview`). This is
// the check that would have caught Nov 2, 2026's outage: the dev server never
// runs production-only code, and a stub that throws in it
// (app_stores_removed) stopped every page from starting.
//
// AniList is blocked, so pages show their own "couldn't load" states; that
// doesn't matter here. What matters is that the app itself runs.

const PAGES = [
	'/',
	'/browse',
	'/seasonal',
	'/schedule',
	'/title/154587',
	'/staff/95185',
	'/character/176754',
	'/list',
	'/profile',
	'/user/matchai',
	'/user/matchai/animelist',
	'/settings',
	'/login',
	'/privacy'
];

/** Blocks AniList, and collects uncaught errors (not failed requests). */
async function watch(page: Page): Promise<string[]> {
	const errors: string[] = [];
	page.on('pageerror', (err) => errors.push(err.message));
	await page.route(/anilist\.co/, (route) => route.abort());
	return errors;
}

const hydrated = (page: Page) => expect(page.locator('html[data-hydrated]')).toBeAttached();

for (const path of PAGES) {
	test(`${path} starts`, async ({ page }) => {
		const errors = await watch(page);
		await page.goto(path);
		await hydrated(page);
		expect(errors).toEqual([]);
	});
}

test('client-side navigation works', async ({ page }) => {
	const errors = await watch(page);
	await page.goto('/');
	await hydrated(page);
	await page.locator('a[href="/browse"]').first().click();
	await expect(page).toHaveURL(/\/browse$/);
	await page.locator('a[href="/seasonal"]').first().click();
	await expect(page).toHaveURL(/\/seasonal$/);
	expect(errors).toEqual([]);
});

test('public pages carry the cache header the edge cache keys on', async ({ request }) => {
	// SSR_ANILIST is off here, so pages render without AniList: what matters is
	// that a personal page is never marked shareable
	for (const path of ['/list', '/settings', '/login']) {
		const cc = (await request.get(path)).headers()['cache-control'] ?? '';
		expect(cc, path).not.toMatch(/s-maxage/);
	}
});
