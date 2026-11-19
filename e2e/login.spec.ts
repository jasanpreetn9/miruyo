import { test, expect } from '@playwright/test';
import { mockBrowse, mockPublicTrending } from './mock-auth.ts';

// the poster wall (public trending) and Browse are mocked in every test here
test.beforeEach(async ({ page }) => {
	await mockPublicTrending(page);
	await mockBrowse(page);
});

test('login shows a working AniList OAuth link', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/login');

	const cta = page.getByRole('link', { name: 'Log in with AniList' });
	await expect(cta).toBeVisible();

	const href = await cta.getAttribute('href');
	expect(href).toContain('https://anilist.co/api/v2/oauth/authorize');
	expect(href).toContain('response_type=token');
	expect(href).not.toContain('redirect_uri=');
	// the state the callback checks, saved for this tab
	await expect(cta).toHaveAttribute('href', /[?&]state=[0-9a-f]{32}/);
	const state = new URL((await cta.getAttribute('href'))!).searchParams.get('state');
	expect(await page.evaluate(() => sessionStorage.getItem('miruyo_oauth_state'))).toBe(state);
});

test('browse without an account skips straight to Browse', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/login');

	await page.getByRole('link', { name: 'Browse without an account' }).click();
	await expect(page).toHaveURL('/browse');
});
