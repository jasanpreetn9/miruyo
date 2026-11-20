import { test, expect } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockBrowse } from './helpers/mock-auth.ts';

// Browse's AniList requests are mocked in every test here
test.beforeEach(async ({ page }) => {
	await mockBrowse(page);
});

test('⌘K opens Browse with the search box focused', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/login');
	await page.keyboard.press('Meta+k');
	await expect(page).toHaveURL('/browse');
	await expect(page.getByLabel('Search', { exact: true }).first()).toBeFocused();
});

test('Ctrl+K focuses search when already on Browse', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/browse');
	await page.getByRole('button', { name: 'Fantasy', exact: true }).focus();
	await page.keyboard.press('Control+k');
	await expect(page.getByLabel('Search', { exact: true }).first()).toBeFocused();
});

test('the top bar search pill opens search', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/browse');
	await page.getByRole('button', { name: 'Fantasy', exact: true }).focus();
	await page.getByRole('banner').getByRole('button', { name: 'Search', exact: true }).click();
	await expect(page.getByLabel('Search', { exact: true }).first()).toBeFocused();
});

test('/search (mobile) opens Browse with search focused', async ({ page }) => {
	await page.setViewportSize({ width: 390, height: 844 });
	await page.goto('/search');
	await expect(page).toHaveURL('/browse');
	await expect(page.getByLabel('Search', { exact: true }).last()).toBeFocused();
});

test('/search?q= carries the query into Browse', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/search?q=frieren');
	await expect(page).toHaveURL('/browse?q=frieren');
	await expect(page.getByLabel('Search', { exact: true }).first()).toHaveValue('frieren');
});
