import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockLoggedIn, type AniListCall } from './helpers/mock-auth.ts';

const settingsSaves = (calls: AniListCall[]) =>
	calls.filter((c) => c.query.includes('mutation UpdateSettings')).map((c) => c.variables);

async function openSettings(page: Page, width = 1440) {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width, height: 900 });
	await gotoHydrated(page, '/settings');
	await expect(page.getByRole('heading', { name: 'Settings', exact: true })).toBeVisible();
	return calls;
}

const radio = (page: Page, group: string, name: string | RegExp) =>
	page.getByTestId(group).getByRole('radio', { name });

test('signed out, Settings asks you to log in', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/settings');
	await expect(
		page.getByRole('heading', { name: 'Settings live on your AniList account' })
	).toBeVisible();
});

test('starts from the account and saves each change to AniList', async ({ page }) => {
	const calls = await openSettings(page);
	await expect(radio(page, 'title-language', /Romaji/)).toHaveAttribute('aria-checked', 'true');
	await expect(radio(page, 'score-format', /10 points, with decimals/)).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await expect(page.getByRole('switch', { name: 'Show adult (18+) titles' })).toHaveAttribute(
		'aria-checked',
		'false'
	);
	await expect(page.getByRole('switch', { name: 'New episodes' })).toHaveAttribute(
		'aria-checked',
		'true'
	);

	await radio(page, 'title-language', /English/).click();
	await expect(page.getByTestId('save-status')).toHaveText(/Saved to AniList/);
	await expect(radio(page, 'title-language', /English/)).toHaveAttribute('aria-checked', 'true');

	await page.getByRole('switch', { name: 'Show adult (18+) titles' }).click();
	await expect(page.getByRole('switch', { name: 'Show adult (18+) titles' })).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await page.getByRole('switch', { name: 'New episodes' }).click();
	await expect(page.getByRole('switch', { name: 'New episodes' })).toHaveAttribute(
		'aria-checked',
		'false'
	);
	await radio(page, 'score-format', /100 points/).click();
	await expect(radio(page, 'score-format', /100 points/)).toHaveAttribute('aria-checked', 'true');

	// one field per save; the earlier choices stay
	expect(settingsSaves(calls)).toEqual([
		{ titleLanguage: 'ENGLISH' },
		{ displayAdultContent: true },
		{ airingNotifications: false },
		{ scoreFormat: 'POINT_100' }
	]);
	await expect(radio(page, 'title-language', /English/)).toHaveAttribute('aria-checked', 'true');
});

test('a refused save rolls back and says so', async ({ page }) => {
	await openSettings(page);
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string };
		if (!body.query.includes('mutation UpdateSettings')) return route.fallback();
		await route.fulfill({
			status: 500,
			contentType: 'application/json',
			body: JSON.stringify({ errors: [{ message: 'Server error', status: 500 }], data: null })
		});
	});

	await radio(page, 'score-format', /5 stars/).click();
	await expect(page.getByTestId('save-status')).toHaveText(/Couldn't save to AniList/);
	await expect(radio(page, 'score-format', /10 points, with decimals/)).toHaveAttribute(
		'aria-checked',
		'true'
	);
});

test('account links, and signing out', async ({ page }) => {
	await openSettings(page);
	await expect(page.getByRole('link', { name: /Revoke access/ })).toHaveAttribute(
		'href',
		'https://anilist.co/settings/apps'
	);
	await page.getByRole('button', { name: /Sign out/ }).click();
	await expect(page).toHaveURL(/\/login$/);
});

test('the avatar menu opens Settings', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');
	await page.getByRole('banner').getByRole('button', { name: 'Account' }).click();
	await page.getByRole('link', { name: 'Settings' }).click();
	await expect(page).toHaveURL(/\/settings$/);
});

test('mobile: Profile → Settings', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/');
	// the tab bar's Profile is your own page, with Settings under your name
	await page.locator('nav.fixed a[href="/user/haruka_k"]').click();
	await expect(page.getByRole('heading', { level: 1, name: 'haruka_k' })).toBeVisible();
	await page.locator('a[href="/settings"]:visible').click();
	await expect(page).toHaveURL(/\/settings$/);
});
