import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import {
	mockDetail,
	mockListCollection,
	mockLoggedIn,
	type AniListCall,
	type MockListEntry
} from './mock-auth.ts';

const ENTRIES: MockListEntry[] = [
	{
		id: 400001,
		title: 'Frieren',
		status: 'CURRENT',
		progress: 6,
		score: 9.5,
		airsIn: 2 * 86400 + 4 * 3600 + 1800, // margin: the countdown floors as seconds pass
		nextEpisode: 9,
		updatedAgo: 2 * 3600
	},
	{
		id: 400002,
		title: 'Apothecary',
		status: 'CURRENT',
		progress: 23,
		episodes: 24,
		updatedAgo: 86400 + 3600
	},
	{
		id: 400003,
		title: 'Dandadan Movie',
		status: 'CURRENT',
		progress: 0,
		episodes: 1,
		format: 'MOVIE',
		updatedAgo: 3 * 86400
	},
	{ id: 400004, title: 'Mob Psycho', status: 'COMPLETED', progress: 12, score: 9 },
	{ id: 400005, title: 'Planned One', status: 'PLANNING', progress: 0 }
];

const saves = (calls: AniListCall[]) =>
	calls.filter((c) => c.query.includes('mutation SaveEntry')).map((c) => c.variables);

async function openList(page: Page, entries = ENTRIES, url = '/list') {
	const calls = await mockLoggedIn(page);
	await mockListCollection(page, entries);
	await mockDetail(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, url);
	return calls;
}

const rows = (page: Page) => page.getByTestId('list-row');

test('signed out, My List asks you to log in', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/list');
	await expect(page.getByRole('heading', { name: 'Your list lives on AniList' })).toBeVisible();
	await expect(page.getByRole('link', { name: 'Log in with AniList' }).last()).toHaveAttribute(
		'href',
		'/login'
	);
});

test('tabs count each status; Watching rows carry airing context', async ({ page }) => {
	await openList(page);
	await expect(page.getByRole('heading', { name: 'haruka_k’s anime' })).toBeVisible();
	await expect(page.getByText('5 titles · 41 episodes', { exact: false })).toBeVisible();

	await expect(page.getByRole('tab', { name: /Watching 3/ })).toHaveAttribute(
		'aria-selected',
		'true'
	);
	await expect(page.getByRole('tab', { name: /Completed 1/ })).toBeVisible();
	await expect(rows(page)).toHaveCount(3);
	const frieren = rows(page).filter({ hasText: 'Frieren' });
	await expect(frieren.getByText('2 new · EP 9 in 2d 4h')).toBeVisible();
	await expect(frieren.getByText('2h ago')).toBeVisible();
	await expect(frieren.getByText('9.5')).toBeVisible();
});

test('the tab is in the URL', async ({ page }) => {
	await openList(page, ENTRIES, '/list?tab=completed');
	await expect(page.getByRole('tab', { name: /Completed/ })).toHaveAttribute(
		'aria-selected',
		'true'
	);
	await expect(rows(page)).toHaveCount(1);
	await page.getByRole('tab', { name: /Planning/ }).click();
	await expect(page).toHaveURL('/list?tab=planning');
	await expect(rows(page).filter({ hasText: 'Planned One' })).toBeVisible();
});

test('+1 saves; reaching the total moves the row to Completed with Undo', async ({ page }) => {
	const calls = await openList(page);
	const apothecary = rows(page).filter({ hasText: 'Apothecary' });
	await apothecary.getByRole('button', { name: /Add one episode/ }).click();

	await expect
		.poll(() => saves(calls))
		.toEqual([{ mediaId: 400002, progress: 24, status: 'COMPLETED' }]);
	await expect(apothecary).toHaveCount(0);
	await expect(page.getByRole('tab', { name: /Completed 2/ })).toBeVisible();

	await page.getByTestId('toast').getByRole('button', { name: 'Undo' }).click();
	await expect(rows(page).filter({ hasText: 'Apothecary' })).toBeVisible();
	await expect(page.getByRole('tab', { name: /Completed 1/ })).toBeVisible();
});

test('+1 on Planning starts it', async ({ page }) => {
	const calls = await openList(page, ENTRIES, '/list?tab=planning');
	await rows(page)
		.filter({ hasText: 'Planned One' })
		.getByRole('button', { name: /Add one episode/ })
		.click();
	await expect
		.poll(() => saves(calls))
		.toEqual([{ mediaId: 400005, progress: 1, status: 'CURRENT' }]);
	await expect(page.getByRole('tab', { name: /Watching 4/ })).toBeVisible();
});

test('click a score to nudge it, ✓ to save', async ({ page }) => {
	const calls = await openList(page);
	const frieren = rows(page).filter({ hasText: 'Frieren' });
	await frieren.getByRole('button', { name: /Score 9.5/ }).click();
	await frieren.getByRole('button', { name: 'Raise score' }).click();
	await frieren.getByRole('button', { name: 'Save score' }).click();
	await expect.poll(() => saves(calls)).toEqual([{ mediaId: 400001, score: 10 }]);
	await expect(frieren.getByRole('button', { name: /Score 10/ })).toBeVisible();
});

test('filter, format and sort narrow and order the tab', async ({ page }) => {
	await openList(page);
	await page.getByRole('searchbox', { name: 'Filter this list' }).fill('apoth');
	await expect(rows(page)).toHaveCount(1);
	await page.getByRole('searchbox', { name: 'Filter this list' }).fill('');

	await page.getByRole('combobox', { name: /Format/ }).selectOption('Movie');
	await expect(rows(page)).toHaveCount(1);
	await expect(rows(page).first()).toContainText('Dandadan Movie');
	await page.getByRole('combobox', { name: /Format/ }).selectOption('');

	await page.getByRole('combobox', { name: /Sort/ }).selectOption('title');
	await expect(rows(page).first()).toContainText('Apothecary');
});

test('grid or table is one choice for every tab, and is remembered', async ({ page }) => {
	await openList(page);
	await page.getByRole('radio', { name: 'Grid' }).click();
	await expect(rows(page)).toHaveCount(0);
	await expect(page.getByRole('group', { name: 'Frieren' })).toBeVisible();

	await page.getByRole('tab', { name: /Completed/ }).click();
	await expect(rows(page)).toHaveCount(0);
	await expect(page.getByRole('group', { name: 'Mob Psycho' })).toBeVisible();
	await expect(page.getByRole('radio', { name: 'Grid' })).toHaveAttribute('aria-checked', 'true');

	await page.reload();
	await expect(page.getByRole('radio', { name: 'Grid' })).toHaveAttribute('aria-checked', 'true');
});

test('a row opens the editor', async ({ page }) => {
	await openList(page);
	const frieren = rows(page).filter({ hasText: 'Frieren' });
	await frieren.hover();
	await frieren.getByRole('button', { name: 'Edit Frieren' }).click();
	await expect(
		page.getByTestId('list-editor').getByRole('heading', { name: 'Frieren' })
	).toBeVisible();
});

test('an empty tab says so and points to Seasonal', async ({ page }) => {
	await openList(page, ENTRIES, '/list?tab=dropped');
	const empty = page.getByTestId('list-empty');
	await expect(empty.getByText('Nothing dropped yet')).toBeVisible();
	await expect(empty.getByRole('link', { name: 'Browse seasonal' })).toHaveAttribute(
		'href',
		'/seasonal'
	);
});

test('long lists render 100 rows at a time', async ({ page }) => {
	const many: MockListEntry[] = Array.from({ length: 150 }, (_, i) => ({
		id: 410000 + i,
		title: `Long ${i + 1}`,
		status: 'CURRENT',
		progress: 1,
		updatedAgo: i * 60 + 60
	}));
	await openList(page, many);
	await expect(rows(page)).toHaveCount(100);
	// reaching the end shows the rest; it can load on its own before a click
	// lands (the rows are measured as they render), so scroll rather than click
	await rows(page).last().scrollIntoViewIfNeeded();
	await expect(rows(page)).toHaveCount(150);
});

test('mobile: compact rows with +1', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await mockListCollection(page, ENTRIES);
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/list');
	const mobileRows = page.getByTestId('list-row-mobile');
	await expect(mobileRows).toHaveCount(3);
	await mobileRows
		.filter({ hasText: 'Frieren' })
		.getByRole('button', { name: /Add one episode/ })
		.click();
	await expect.poll(() => saves(calls)).toEqual([{ mediaId: 400001, progress: 7 }]);
});

test('Watching opens on Most to watch, and a link can set the sort', async ({ page }) => {
	await openList(page, ENTRIES, '/list?sort=title');
	const sort = page.getByRole('combobox', { name: /Sort/ });
	await expect(sort).toHaveValue('title');
	await expect(rows(page).first()).toContainText('Apothecary');

	// the tab's own default leaves the URL
	await sort.selectOption('toWatch');
	await expect(page).toHaveURL('/list');
	await expect(rows(page).first()).toContainText('Frieren');

	// Most to watch is only on the tabs you're in the middle of
	await page.getByRole('tab', { name: /Completed/ }).click();
	await expect(sort).toHaveValue('updated');
	await expect(sort.locator('option[value="toWatch"]')).toHaveCount(0);
});

test('custom lists are tabs of their own, after the statuses', async ({ page }) => {
	await openList(page, [
		...ENTRIES.map((e) =>
			e.id === 400004 || e.id === 400005 ? { ...e, lists: ['Rewatch someday'] } : e
		),
		{
			id: 400006,
			title: 'Hidden Gem',
			status: 'COMPLETED',
			progress: 12,
			lists: ['Rewatch someday'],
			hidden: true
		}
	]);
	// hidden from status lists: not under Completed
	await expect(page.getByRole('tab', { name: /Completed 1/ })).toBeVisible();

	const tab = page.getByRole('tab', { name: /Rewatch someday 3/ });
	await tab.click();
	await expect(page).toHaveURL('/list?list=Rewatch%20someday');
	await expect(tab).toHaveAttribute('aria-selected', 'true');
	await expect(page.getByRole('tab', { name: /Watching/ })).toHaveAttribute(
		'aria-selected',
		'false'
	);
	// every status on it, each saying which
	await expect(rows(page)).toHaveCount(3);
	await expect(rows(page).filter({ hasText: 'Planned One' })).toContainText('Planning ·');
	await expect(rows(page).filter({ hasText: 'Hidden Gem' })).toContainText('Completed ·');

	await page.getByRole('tab', { name: /Watching/ }).click();
	await expect(page).toHaveURL('/list');
	await expect(rows(page)).toHaveCount(3);
});

test('back after a minute, the list shows at once, edits kept, while a newer copy loads', async ({
	page
}) => {
	await page.clock.install();
	const entries = ENTRIES.map((e) => ({ ...e }));
	const calls = await openList(page, entries);
	const frieren = () => rows(page).filter({ hasText: 'Frieren' });
	await expect(frieren()).toContainText(/\b6\b/);
	await frieren()
		.getByRole('button', { name: /Add one episode/ })
		.click();
	await expect.poll(() => saves(calls)).toEqual([{ mediaId: 400001, progress: 7 }]);

	// the next list request holds until released
	let release!: () => void;
	const held = new Promise<void>((r) => (release = r));
	let asked = 0;
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string };
		if (body.query.includes('query ListCollection')) {
			asked++;
			await held;
		}
		await route.fallback();
	});

	await page.clock.fastForward('01:05');
	await page.getByRole('link', { name: 'Home' }).first().click();
	await expect(page).toHaveURL(/\/$/);
	await page.getByRole('link', { name: 'My List' }).first().click();
	// the saved copy, at once, with the +1 on it, though it predates the save
	await expect(frieren()).toContainText(/\b7\b/);
	await expect.poll(() => asked).toBeGreaterThan(0);

	// AniList's newer copy lands behind it: the +1, and a change made
	// elsewhere (Apothecary, 23 → 20), which shows without leaving the page
	const apothecary = rows(page).filter({ hasText: 'Apothecary' });
	await expect(apothecary).toContainText(/\b23\b/);
	entries[0].progress = 7;
	entries[1].progress = 20;
	release();
	await expect(apothecary).toContainText(/\b20\b/);
	await expect(frieren()).toContainText(/\b7\b/);
});
