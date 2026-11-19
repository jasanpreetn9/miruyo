import { test, expect } from '@playwright/test';

test('unknown routes show the 404 page with a way back', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	const response = await page.goto('/no-such-page');
	expect(response?.status()).toBe(404);

	await expect(page.getByRole('heading', { name: 'This page doesn’t exist yet' })).toBeVisible();

	await page.getByRole('link', { name: 'Go home' }).click();
	await expect(page).toHaveURL('/');
});
