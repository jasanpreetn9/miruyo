import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockLoggedIn } from './helpers/mock-auth.ts';

/** Lands on the callback as AniList's redirect would, for a sign-in this tab started. */
async function returnFromAniList(page: Page) {
	await page.addInitScript(() => sessionStorage.setItem('miruyo_oauth_state', 'state-1'));
	await page.goto('/api/callback#access_token=fresh-token&token_type=Bearer&state=state-1');
}

test('first sign-in goes through setup, which saves to AniList and opens Home', async ({
	page
}) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 390, height: 844 });
	// AniList's OAuth redirect lands here with the token in the hash
	await returnFromAniList(page);
	await expect(page).toHaveURL('/welcome');

	await expect(page.getByText('Connected as haruka_k.')).toBeVisible();
	await expect(page.getByText('Imported 167 anime and 97 manga.')).toBeVisible();
	await expect(page.getByRole('radio', { name: 'Romaji' })).toHaveAttribute('aria-checked', 'true');

	await page.getByRole('radio', { name: 'Manga' }).click();
	await page.getByRole('radio', { name: 'English' }).click();
	await page.getByRole('switch', { name: 'Show adult (18+) titles' }).click();
	await page.getByRole('button', { name: 'Continue' }).click();

	await expect(page).toHaveURL('/');
	await expect(page.getByRole('heading', { name: 'Continue reading' })).toBeVisible();
	expect(calls.find((c) => c.query.includes('mutation UpdateSettings'))?.variables).toEqual({
		titleLanguage: 'ENGLISH',
		displayAdultContent: true
	});
	expect(await page.evaluate(() => localStorage.getItem('miruyo_mode'))).toBe('manga');
	expect(await page.evaluate(() => localStorage.getItem('miruyo_onboarded'))).toBe('1');
});

test("setup doesn't touch AniList when nothing changed", async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await gotoHydrated(page, '/welcome');
	await page.getByRole('button', { name: 'Continue' }).click();
	await expect(page).toHaveURL('/');
	expect(calls.some((c) => c.query.includes('mutation UpdateSettings'))).toBe(false);
});

test('later sign-ins skip setup', async ({ page }) => {
	await mockLoggedIn(page);
	await page.addInitScript(() => localStorage.setItem('miruyo_onboarded', '1'));
	await returnFromAniList(page);
	await expect(page).toHaveURL('/');
	await expect(
		page.getByTestId('continue-row').filter({ hasText: 'Mock Continue Anime' })
	).toBeVisible();
});

test("a token from a sign-in this tab didn't start is refused", async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.addInitScript(() => localStorage.removeItem('anilist_token'));
	await page.goto('/api/callback#access_token=planted-token&token_type=Bearer&state=forged');
	await expect(page.getByText('Authentication Failed')).toBeVisible();
	expect(await page.evaluate(() => localStorage.getItem('anilist_token'))).toBeNull();
	expect(calls.some((c) => c.query.includes('Viewer'))).toBe(false);
});

test('signed out, setup sends you to log in', async ({ page }) => {
	await page.goto('/welcome');
	await expect(page).toHaveURL('/login');
});
