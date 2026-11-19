import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockDetail, mockLoggedIn, type AniListCall } from './mock-auth.ts';

const saves = (calls: AniListCall[]) =>
	calls.filter((c) => c.query.includes('mutation SaveEntry')).map((c) => c.variables);

/** The browser's own "today", as AniList's date shape. */
async function today(page: Page) {
	return page.evaluate(() => {
		const d = new Date();
		return { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate() };
	});
}

async function openEditor(page: Page, entry?: Parameters<typeof mockDetail>[1]['entry']) {
	const calls = await mockLoggedIn(page);
	const detailCalls = await mockDetail(page, { entry });
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/title/300100');
	await page.getByRole('complementary').getByTestId('detail-status').click();
	const editor = page.getByTestId('list-editor');
	await expect(editor).toBeVisible();
	return { calls, detailCalls, editor };
}

test('completing fills progress and the finish date, and saves only what changed', async ({
	page
}) => {
	const { calls, detailCalls, editor } = await openEditor(page, {
		status: 'CURRENT',
		progress: 7,
		score: 9.5,
		startedAt: { year: 2026, month: 10, day: 2 }
	});
	// opened from the page: the full entry is fetched
	await expect.poll(() => detailCalls.some((c) => c.query.includes('query Entry'))).toBe(true);
	await expect(editor.getByRole('radio', { name: 'Watching', exact: true })).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await expect(editor.getByRole('spinbutton')).toHaveValue('7');

	await editor.getByRole('radio', { name: 'Completed', exact: true }).click();
	await expect(editor.getByRole('spinbutton')).toHaveValue('28');
	await editor.getByRole('button', { name: 'Save' }).click();

	await expect(editor.getByText('Saved to AniList ✓')).toBeVisible();
	expect(saves(calls)).toEqual([
		{ mediaId: 300100, status: 'COMPLETED', progress: 28, completedAt: await today(page) }
	]);
	await editor.getByRole('button', { name: 'Done' }).click();
	await expect(editor).toHaveCount(0);
	await expect(page.getByRole('complementary').getByTestId('detail-status')).toContainText(
		'Completed'
	);
});

test('custom lists: the editor shows every one, toggles them, and saves the set', async ({
	page
}) => {
	const calls = await mockLoggedIn(page);
	await mockDetail(page, {
		entry: {
			status: 'CURRENT',
			progress: 7,
			customLists: [
				{ name: 'Rewatch someday', enabled: true },
				{ name: 'Comfort shows', enabled: false }
			]
		}
	});
	// the account's lists, an empty one too (the list collection leaves those out)
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (!query.includes('query GetViewer')) return route.fallback();
		await route.fulfill({
			json: {
				data: {
					Viewer: {
						id: 1,
						name: 'haruka_k',
						avatar: { large: '', medium: '' },
						bannerImage: null,
						unreadNotificationCount: 0,
						mediaListOptions: {
							scoreFormat: 'POINT_10_DECIMAL',
							animeList: { customLists: ['Rewatch someday', 'Comfort shows', 'Empty one'] },
							mangaList: { customLists: [] }
						},
						options: {
							titleLanguage: 'ROMAJI',
							displayAdultContent: false,
							airingNotifications: true
						}
					}
				}
			}
		});
	});
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/title/300100');
	await page.getByRole('complementary').getByTestId('detail-status').click();
	const editor = page.getByTestId('list-editor');
	const lists = editor.getByRole('group', { name: 'Custom lists' });
	await expect(lists.getByRole('button')).toHaveText(
		['Rewatch someday', 'Comfort shows', 'Empty one'].map((n) => new RegExp(n))
	);
	await expect(lists.getByRole('button', { name: /Rewatch someday/ })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
	await expect(lists.getByRole('button', { name: /Empty one/ })).toHaveAttribute(
		'aria-pressed',
		'false'
	);

	await lists.getByRole('button', { name: /Rewatch someday/ }).click();
	await lists.getByRole('button', { name: /Empty one/ }).click();
	await editor.getByRole('button', { name: 'Save' }).click();
	await expect(editor.getByText('Saved to AniList ✓')).toBeVisible();
	// the whole set, in the account's order; nothing else changed
	expect(saves(calls)).toEqual([{ mediaId: 300100, customLists: ['Empty one'] }]);

	// Undo puts the lists it was on back
	await editor.getByRole('button', { name: 'Done' }).click();
	await page.getByRole('button', { name: 'Undo' }).click();
	await expect.poll(() => saves(calls).length).toBe(2);
	expect(saves(calls)[1]).toMatchObject({ customLists: ['Rewatch someday'] });
});

test("custom lists can't be toggled until the entry's own lists have loaded", async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page, {
		entry: {
			status: 'CURRENT',
			progress: 7,
			customLists: [{ name: 'Rewatch someday', enabled: true }]
		}
	});
	// the full entry is slow to arrive
	let release = () => {};
	const held = new Promise<void>((r) => (release = r));
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (query.includes('query Entry')) await held;
		return route.fallback();
	});
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (!query.includes('query GetViewer')) return route.fallback();
		await route.fulfill({
			json: {
				data: {
					Viewer: {
						id: 1,
						name: 'haruka_k',
						avatar: { large: '', medium: '' },
						bannerImage: null,
						unreadNotificationCount: 0,
						mediaListOptions: {
							scoreFormat: 'POINT_10_DECIMAL',
							animeList: { customLists: ['Rewatch someday', 'Comfort shows'] },
							mangaList: { customLists: [] }
						},
						options: {
							titleLanguage: 'ROMAJI',
							displayAdultContent: false,
							airingNotifications: true
						}
					}
				}
			}
		});
	});
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/title/300100');
	await page.getByRole('complementary').getByTestId('detail-status').click();
	const lists = page.getByTestId('list-editor').getByRole('group', { name: 'Custom lists' });
	// a toggle now would send a set that leaves out 'Rewatch someday'
	await expect(lists.getByRole('button', { name: /Comfort shows/ })).toBeDisabled();
	release();
	await expect(lists.getByRole('button', { name: /Comfort shows/ })).toBeEnabled();
	await expect(lists.getByRole('button', { name: /Rewatch someday/ })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
});

test('the score uses the account’s format: a second click takes off half a point', async ({
	page
}) => {
	const { calls, editor } = await openEditor(page, { status: 'CURRENT', progress: 7 });
	await editor.getByRole('button', { name: 'Score 8' }).click();
	await editor.getByRole('button', { name: 'Score 8' }).click();
	await expect(editor.getByText('7.5 / 10')).toBeVisible();
	await editor.getByRole('button', { name: 'Save' }).click();
	await expect.poll(() => saves(calls)).toEqual([{ mediaId: 300100, score: 7.5 }]);
});

test('closing with unsaved edits asks once', async ({ page }) => {
	const { editor } = await openEditor(page, { status: 'CURRENT', progress: 7 });
	await editor.getByRole('textbox', { name: 'Notes' }).fill('Rewatch EP 1');

	await page.keyboard.press('Escape');
	await expect(editor.getByText('Discard your changes?')).toBeVisible();
	await editor.getByRole('button', { name: 'Keep editing' }).click();
	await expect(editor.getByRole('textbox', { name: 'Notes' })).toHaveValue('Rewatch EP 1');

	await editor.getByRole('button', { name: 'Close editor' }).click();
	await editor.getByRole('button', { name: 'Discard' }).click();
	await expect(editor).toHaveCount(0);
});

test('reaching the last episode moves the draft to Completed, with Undo', async ({ page }) => {
	const { calls, editor } = await openEditor(page, { status: 'CURRENT', progress: 26 });
	await editor.getByRole('button', { name: 'One more episode' }).click();
	await expect(editor.getByRole('radio', { name: 'Watching', exact: true })).toHaveAttribute(
		'aria-checked',
		'true'
	);

	await editor.getByRole('button', { name: 'One more episode' }).click();
	await expect(editor.getByText('Last episode — moved to Completed.')).toBeVisible();
	await expect(editor.getByRole('radio', { name: 'Completed', exact: true })).toHaveAttribute(
		'aria-checked',
		'true'
	);

	// Undo in the editor keeps the progress but restores the status
	await editor.getByRole('button', { name: 'Undo' }).click();
	await expect(editor.getByRole('radio', { name: 'Watching', exact: true })).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await expect(editor.getByRole('spinbutton')).toHaveValue('28');

	await editor.getByRole('radio', { name: 'Completed', exact: true }).click();
	await editor.getByRole('button', { name: 'Save' }).click();
	await expect
		.poll(() => saves(calls))
		.toEqual([
			{ mediaId: 300100, status: 'COMPLETED', progress: 28, completedAt: await today(page) }
		]);
});

test('delete asks first, then removes the entry from AniList', async ({ page }) => {
	const { calls, editor } = await openEditor(page, { status: 'CURRENT', progress: 7 });
	await editor.getByRole('button', { name: 'Delete' }).click();
	await expect(editor.getByText('Remove it from your list?')).toBeVisible();
	await editor.getByRole('button', { name: 'Remove' }).click();

	await expect(editor).toHaveCount(0);
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation DeleteEntry'))?.variables)
		.toEqual({ id: 3001000 });
	await expect(page.getByRole('complementary').getByTestId('detail-status')).toContainText(
		'Add to list'
	);
});

test('"Open full editor" on a card not on the list adds it', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await mockDetail(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.emulateMedia({ reducedMotion: 'reduce' });
	await gotoHydrated(page, '/');

	const card = page.getByRole('group', { name: 'Mock Trending One' }).last();
	await card.evaluate((el) => el.scrollIntoView({ block: 'center' }));
	await card.hover();
	await card.getByRole('button', { name: 'More options' }).click();
	await page.getByRole('menuitem', { name: 'Open full editor' }).click();

	const editor = page.getByTestId('list-editor');
	await expect(editor.getByRole('heading', { name: 'Mock Trending One' })).toBeVisible();
	await expect(editor.getByRole('radio', { name: 'Planning' })).toHaveAttribute(
		'aria-checked',
		'true'
	);
	await editor.getByRole('button', { name: 'Add to list' }).click();
	await expect.poll(() => saves(calls)).toEqual([{ mediaId: 200002, status: 'PLANNING' }]);
});

test('mobile: a bottom sheet with the less-used fields folded into rows', async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page, { entry: { status: 'CURRENT', progress: 7 } });
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/title/300100');
	await page.getByTestId('detail-status').last().click();

	const editor = page.getByTestId('list-editor');
	await expect(editor.getByLabel('Started')).toBeHidden();
	await editor.getByRole('button', { name: /^Dates/ }).click();
	await expect(editor.getByLabel('Started')).toBeVisible();
	await expect(editor.getByRole('textbox', { name: 'Notes' })).toBeHidden();
});
