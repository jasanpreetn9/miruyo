import { test, expect } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockDetail, mockLoggedIn } from './helpers/mock-auth.ts';

test('adding a title says so, and Undo takes it off again', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await gotoHydrated(page, '/');

	const card = page.getByRole('group', { name: 'Mock Trending Two' }).last();
	await card.evaluate((el) => el.scrollIntoView({ block: 'center' }));
	await card.hover();
	await card.getByRole('button', { name: 'Planning' }).click();

	const toast = page.getByTestId('toast');
	await expect(toast).toContainText('Added Mock Trending Two to Planning');
	await toast.getByRole('button', { name: 'Undo' }).click();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation DeleteEntry'))?.variables)
		.toEqual({ id: 900000 + 200003 });
	await expect(card.getByText('Planning', { exact: true }).filter({ visible: true })).toHaveCount(
		0
	);
});

test('changing status says where it moved', async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page, { entry: { status: 'CURRENT', progress: 5 } });
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('complementary').getByTestId('detail-status').click();
	const editor = page.getByTestId('list-editor');
	await editor.getByRole('radio', { name: 'Paused', exact: true }).click();
	await editor.getByRole('button', { name: 'Save' }).click();
	await expect(page.getByTestId('toast')).toContainText('Moved Sousou no Frieren to Paused');
});

test('removing says so, and Undo adds it back as it was', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await mockDetail(page, { entry: { status: 'CURRENT', progress: 5, score: 8 } });
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('complementary').getByTestId('detail-status').click();
	const editor = page.getByTestId('list-editor');
	await editor.getByRole('button', { name: 'Delete' }).click();
	await editor.getByRole('button', { name: 'Remove' }).click();

	const toast = page.getByTestId('toast');
	await expect(toast).toContainText('Removed Sousou no Frieren from your list');
	await toast.getByRole('button', { name: 'Undo' }).click();
	await expect
		.poll(() => calls.filter((c) => c.query.includes('mutation SaveEntry')).at(-1)?.variables)
		.toMatchObject({ mediaId: 300100, status: 'CURRENT', progress: 5, score: 8 });
	await expect(page.getByRole('complementary').getByTestId('detail-status')).toContainText(
		'Watching'
	);
});
