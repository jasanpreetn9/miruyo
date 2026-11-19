import { test, expect, type Locator } from '@playwright/test';
import { mockLoggedIn } from './mock-auth.ts';

/**
 * Hover a card to reveal its overlay. Under reduced motion the lift and slide
 * become fades, so the overlay's buttons don't move while Playwright clicks.
 */
async function hoverCard(card: Locator) {
	await card.page().emulateMedia({ reducedMotion: 'reduce' });
	await card.evaluate((el) => el.scrollIntoView({ block: 'center' }));
	await card.hover();
}

test('+1 saves to AniList and updates every card for the title', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const row = page.getByTestId('continue-row').filter({ hasText: 'Mock Continue Anime' });
	await expect(row).toContainText('EP 5 / 24');
	await expect(page.getByTestId('continue-summary')).toContainText('19 new episodes');
	await row.getByRole('button', { name: 'Add one episode to Mock Continue Anime' }).click();

	// the row and the summary over it read the same entry
	await expect(row).toContainText('EP 6 / 24');
	await expect(page.getByTestId('continue-summary')).toContainText('18 new episodes');

	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 200001, progress: 6 });
});

test('reaching the total completes it, with an Undo toast', async ({ page }) => {
	const calls = await mockLoggedIn(page, 'haruka_k', { progress: 23 });
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	const saves = () =>
		calls.filter((c) => c.query.includes('mutation SaveEntry')).map((c) => c.variables);

	const row = page.getByTestId('continue-row').filter({ hasText: 'Mock Continue Anime' });
	await row.getByRole('button', { name: 'Add one episode to Mock Continue Anime' }).click();
	await expect.poll(saves).toEqual([{ mediaId: 200001, progress: 24, status: 'COMPLETED' }]);
	const toast = page.getByTestId('toast');
	await expect(toast).toContainText('Mock Continue Anime moved to Completed');
	// completed, it leaves Continue
	await expect(row).toHaveCount(0);

	// Undo puts it back the way it was
	await toast.getByRole('button', { name: 'Undo' }).click();
	await expect
		.poll(() => saves().at(-1))
		.toEqual({ mediaId: 200001, status: 'CURRENT', progress: 23 });
	await expect(toast).toHaveCount(0);
	await expect(row).toContainText('EP 23 / 24');
});

test('the status menu adds a title to the list', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const card = page.getByRole('group', { name: 'Mock Trending Two' }).last();
	await hoverCard(card);
	await card.getByRole('button', { name: 'More options' }).click();

	const menu = page.getByRole('menu');
	const names = await menu
		.getByRole('menuitemradio')
		.evaluateAll((items) => items.map((el) => el.querySelector('.flex-1')?.textContent?.trim()));
	expect(names).toEqual(['Watching', 'Completed', 'Planning', 'Paused', 'Dropped', 'Rewatching']);
	await menu.getByRole('menuitemradio', { name: 'Watching', exact: true }).click();
	await expect(menu).toHaveCount(0);

	await expect(card.getByText('Watching · 0/24').filter({ visible: true })).toBeVisible();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 200003, status: 'CURRENT' });
});

test('the status menu works from the keyboard and closes on Escape', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const card = page.getByRole('group', { name: 'Mock Trending One' }).last();
	await hoverCard(card);
	await card.getByRole('button', { name: 'More options' }).click();
	await expect(page.getByRole('menuitemradio', { name: 'Watching', exact: true })).toBeFocused();
	await page.keyboard.press('ArrowDown');
	await expect(page.getByRole('menuitemradio', { name: 'Completed', exact: true })).toBeFocused();
	await page.keyboard.press('Escape');
	await expect(page.getByRole('menu')).toHaveCount(0);
});

test('manga mode uses read verbs in the status menu', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	await expect(
		page.getByTestId('continue-row').filter({ hasText: 'Mock Continue Anime' })
	).toBeVisible();
	await page.getByTestId('toggle-manga').click();
	await expect(
		page.getByRole('button', { name: 'Add one chapter to Mock Continue Anime' })
	).toBeVisible();

	const card = page.getByRole('group', { name: 'Mock Trending One' }).last();
	await hoverCard(card);
	await card.getByRole('button', { name: 'More options' }).click();
	await expect(page.getByRole('menuitemradio', { name: 'Reading', exact: true })).toBeVisible();
	await expect(page.getByRole('menuitemradio', { name: 'Rereading', exact: true })).toBeVisible();
});

test('the status menu escapes the lifted card instead of being clipped by it', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	// full motion: the hover lift transforms the card, which used to trap the menu
	const card = page.getByRole('group', { name: 'Mock Trending Two' }).last();
	await card.evaluate((el) => el.scrollIntoView({ block: 'center' }));
	await card.hover();
	// open from the keyboard so the mouse stays put and the card stays lifted
	await card.getByRole('button', { name: 'More options' }).focus();
	await page.keyboard.press('Enter');

	const menu = page.getByRole('menu');
	await expect(menu).toBeVisible();
	expect(
		await card.locator('.aspect-2\\/3').evaluate((el) => getComputedStyle(el).transform)
	).not.toBe('none');
	expect(await menu.evaluate((el) => el.parentElement === document.body)).toBe(true);
	const box = await menu.boundingBox();
	expect(box?.width).toBe(220);
	await menu.getByRole('menuitemradio', { name: 'Paused', exact: true }).click();
	await expect(card.getByText('Paused · 0/24').filter({ visible: true })).toBeVisible();
});

test('cards already on the list get the same hover row, with a next step for their status', async ({
	page
}) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	const saves = () =>
		calls.filter((c) => c.query.includes('mutation SaveEntry')).map((c) => c.variables);

	const card = page.getByRole('group', { name: 'Mock Trending Two' }).last();
	await hoverCard(card);
	await card.getByRole('button', { name: 'Planning' }).click();
	await expect.poll(saves).toEqual([{ mediaId: 200003, status: 'PLANNING' }]);

	// now on the list: the hover row shows its status, a next step and the menu
	await expect(card.getByText('Planning', { exact: true }).filter({ visible: true })).toBeVisible();
	await expect(card.getByRole('button', { name: 'Manage list entry' })).toBeVisible();
	await card.getByRole('button', { name: 'Start watching' }).click();
	await expect.poll(saves).toContainEqual({ mediaId: 200003, status: 'CURRENT' });

	await card.getByRole('button', { name: 'Add one episode' }).first().click();
	await expect.poll(saves).toContainEqual({ mediaId: 200003, progress: 1 });

	// the menu still offers every status
	await card.getByRole('button', { name: 'Manage list entry' }).click();
	await expect(page.getByRole('menuitemradio', { name: 'Watching', exact: true })).toHaveAttribute(
		'aria-checked',
		'true'
	);
});

test('+1 and −1 each say what changed, with Undo', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	const saves = () =>
		calls.filter((c) => c.query.includes('mutation SaveEntry')).map((c) => c.variables);
	const toast = page.getByTestId('toast');

	const row = page.getByTestId('continue-row').filter({ hasText: 'Mock Continue Anime' });
	await row.getByRole('button', { name: 'Add one episode to Mock Continue Anime' }).click();
	await expect(toast).toContainText('Mock Continue Anime · EP 6 / 24');
	await toast.getByRole('button', { name: 'Undo' }).click();
	await expect.poll(() => saves().at(-1)).toMatchObject({ mediaId: 200001, progress: 5 });
	await expect(row).toContainText('EP 5 / 24');
});

test('Upcoming: the chevron adds to any list', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const chevron = page.getByRole('button', { name: 'More list options for Mock Upcoming One' });
	// the menu closes on scroll, so bring the card into view first
	await chevron.evaluate((el) => el.scrollIntoView({ block: 'center' }));
	await chevron.click();
	await page.getByRole('menuitemradio', { name: 'Watching', exact: true }).click();
	await expect(page.getByTestId('toast')).toContainText('Added Mock Upcoming One to Watching');
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toMatchObject({ status: 'CURRENT' });
});
