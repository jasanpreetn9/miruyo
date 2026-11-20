import type { Page } from '@playwright/test';

/**
 * Navigates and waits until the app has hydrated (the root layout sets
 * `data-hydrated` on <html> in onMount), so clicks aren't lost on
 * server-rendered markup that isn't interactive yet.
 */
export async function gotoHydrated(page: Page, url: string) {
	await page.goto(url);
	await page.locator('html[data-hydrated]').waitFor({ state: 'attached' });
}
