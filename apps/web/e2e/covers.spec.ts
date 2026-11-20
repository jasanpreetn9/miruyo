import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockListCollection, mockLoggedIn } from './helpers/mock-auth.ts';

const HOST = 'https://img.miruyo.test';
// a 1×1 PNG
const PIXEL = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
	'base64'
);

/**
 * The shared mocks have no cover images; give every title one, served as a
 * pixel, by filling in AniList's responses on their way into the app.
 */
async function withCovers(page: Page): Promise<string[]> {
	const requested: string[] = [];
	await page.route(`${HOST}/**`, (route) => {
		requested.push(route.request().url());
		return route.fulfill({ contentType: 'image/png', body: PIXEL });
	});
	await page.addInitScript((host) => {
		const fetch = window.fetch.bind(window);
		window.fetch = async (input, init) => {
			const res = await fetch(input, init);
			const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
			if (!url.includes('graphql.anilist.co')) return res;
			const data = await res.clone().json();
			const walk = (v: unknown): void => {
				if (Array.isArray(v)) return v.forEach(walk);
				if (!v || typeof v !== 'object') return;
				const o = v as Record<string, unknown>;
				if (o.coverImage && typeof o.id === 'number')
					o.coverImage = {
						...(o.coverImage as object),
						extraLarge: `${host}/${o.id}-xl.png`,
						large: `${host}/${o.id}.png`
					};
				Object.values(o).forEach(walk);
			};
			walk(data);
			return new Response(JSON.stringify(data), { status: res.status, headers: res.headers });
		};
	}, HOST);
	return requested;
}

test('covers are lazy images that fade in over their colour', async ({ page }) => {
	const requested = await withCovers(page);
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');

	const card = page.getByRole('group', { name: 'Mock Trending One' }).last();
	await card.scrollIntoViewIfNeeded();
	const cover = card.locator('img');
	await expect(cover).toHaveAttribute('loading', 'lazy');
	await expect(cover).toHaveAttribute('src', /-xl\.png$/);
	// the frame shows the title's colour until the image arrives, then it fades in
	await expect(cover).toHaveClass(/opacity-100/);
	expect(requested.some((u) => u.endsWith('-xl.png'))).toBe(true);
});

test('My List thumbnails load the small cover', async ({ page }) => {
	await withCovers(page);
	await mockLoggedIn(page);
	await mockListCollection(page, [
		{ id: 400001, title: 'Frieren', status: 'CURRENT', progress: 6 }
	]);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/list');

	const thumb = page.getByTestId('list-row').first().locator('img');
	await expect(thumb).toHaveAttribute('src', /\/\d+\.png$/);
	await expect(thumb).toHaveClass(/opacity-100/);
});
