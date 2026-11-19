import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockBrowse, mockLoggedIn } from './mock-auth.ts';

const desktop = async (page: Page) => page.setViewportSize({ width: 1440, height: 900 });
const results = (page: Page) => page.getByTestId('browse-results');

test('browse shows live results, and a genre filters them through the URL', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	// 30 of 36 loaded: AniList's total isn't real until the last page
	await expect(results(page).getByText('30+', { exact: true })).toBeVisible();
	await expect(
		results(page).getByRole('group', { name: 'Mock Browse 1', exact: true })
	).toBeVisible();

	await page
		.getByRole('complementary', { name: 'Filters' })
		.getByRole('button', { name: 'Fantasy', exact: true })
		.click();
	await expect(page).toHaveURL('/browse?genre=Fantasy');
	await expect.poll(() => calls.at(-1)?.genres).toEqual(['Fantasy']);
	await expect(results(page).getByText('7', { exact: true })).toBeVisible();
	await expect(
		results(page).getByRole('group', { name: "Frieren: Beyond Journey's End" })
	).toBeVisible();

	// the chip mirrors the rail, and either can undo it
	await results(page).getByRole('button', { name: 'Remove filter: Fantasy' }).click();
	await expect(page).toHaveURL('/browse');
	await expect(results(page).getByText('30+', { exact: true })).toBeVisible();
});

test('the back button walks back through filter changes', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');
	const rail = page.getByRole('complementary', { name: 'Filters' });

	await rail.getByRole('button', { name: 'Drama', exact: true }).click();
	await expect(page).toHaveURL('/browse?genre=Drama');
	await rail.getByRole('checkbox', { name: 'TV', exact: true }).click();
	await expect(page).toHaveURL('/browse?genre=Drama&format=TV');

	await page.goBack();
	await expect(page).toHaveURL('/browse?genre=Drama');
	await expect(rail.getByRole('checkbox', { name: 'TV', exact: true })).toHaveAttribute(
		'aria-checked',
		'false'
	);
	await expect(rail.getByRole('button', { name: 'Drama', exact: true })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
});

test('a shared link opens with its filters applied', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse?genre=Drama&sort=score&min=7&view=list');

	await expect
		.poll(() => calls.at(-1))
		.toMatchObject({ genres: ['Drama'], sort: ['SCORE_DESC'], scoreAbove: 69 });
	const main = results(page);
	await expect(main.getByRole('button', { name: 'Remove filter: Drama' })).toBeVisible();
	await expect(main.getByRole('button', { name: 'Remove filter: Score ≥ 7.0' })).toBeVisible();
	await expect(main.getByText('Title', { exact: true })).toBeVisible();
	await expect(main.getByRole('combobox')).toHaveValue('score');
});

test('typing searches after a pause; Escape clears it', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	const search = page.getByLabel('Search', { exact: true }).first();
	await search.fill('frieren');
	await expect(page).toHaveURL('/browse?q=frieren');
	await expect.poll(() => calls.at(-1)?.search).toBe('frieren');
	await expect(results(page).getByText('1', { exact: true })).toBeVisible();

	await search.press('Escape');
	await expect(page).toHaveURL('/browse');
	await expect(search).toHaveValue('');
});

test('sort and view live in the URL', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	await results(page).getByRole('combobox').selectOption('score');
	await expect(page).toHaveURL('/browse?sort=score');
	await expect.poll(() => calls.at(-1)?.sort).toEqual(['SCORE_DESC']);

	await page.getByRole('radio', { name: 'Compact list' }).click();
	await expect(page).toHaveURL('/browse?sort=score&view=list');
	await expect(results(page).getByText('Title', { exact: true })).toBeVisible();
	await page.getByRole('radio', { name: 'Grid' }).click();
	await expect(page).toHaveURL('/browse?sort=score');
});

test('tags are searchable and become filters', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');
	const rail = page.getByRole('complementary', { name: 'Filters' });

	await rail.getByRole('textbox', { name: 'Tags' }).fill('elf');
	await rail.getByRole('button', { name: /^Elf/ }).click();
	await expect(page).toHaveURL('/browse?tag=Elf');
	await expect.poll(() => calls.at(-1)?.tags).toEqual(['Elf']);
	await expect(rail.getByRole('button', { name: 'Remove tag Elf' })).toBeVisible();
});

test('more results load at the end of the list', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	await expect(results(page).getByRole('group', { name: /^Mock Browse/ })).toHaveCount(29);
	await results(page).getByRole('button', { name: 'Load more' }).scrollIntoViewIfNeeded();
	await expect.poll(() => calls.some((c) => c.page === 2)).toBe(true);
	await expect(results(page).getByRole('group', { name: /^Mock Browse/ })).toHaveCount(35);
	await expect(results(page).getByRole('button', { name: 'Load more' })).toHaveCount(0);
	// every page is in, so the count is exact now
	await expect(results(page).getByText('36', { exact: true })).toBeVisible();
});

test('no results suggests the closest match without the filters', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse?q=frieren&format=MOVIE');

	const empty = page.getByTestId('no-results').first();
	await expect(empty.getByText('Nothing for “frieren”')).toBeVisible();
	await expect(empty.getByText('You also have 1 filter on.', { exact: false })).toBeVisible();
	await empty.getByRole('button', { name: "Search “Frieren: Beyond Journey's End”" }).click();
	await expect(page).toHaveURL(/q=Frieren/);
	await expect(page).not.toHaveURL(/format=/);
	await expect(results(page).getByText('1', { exact: true })).toBeVisible();
});

test('signed out, there is no hide-on-list filter and adding leads to log in', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	await expect(page.getByRole('switch', { name: /Hide titles on my list/ })).toHaveCount(0);
	await page.emulateMedia({ reducedMotion: 'reduce' });
	const card = results(page).getByRole('group', { name: 'Mock Browse 1', exact: true });
	await card.hover();
	await card.getByRole('button', { name: 'Planning' }).click();
	await expect(page).toHaveURL('/login');
});

test('signed in, hiding titles on the list filters on AniList', async ({ page }) => {
	await mockLoggedIn(page);
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');

	await page.getByRole('switch', { name: /Hide titles on my list/ }).click();
	await expect(page).toHaveURL('/browse?hide=1');
	await expect.poll(() => calls.at(-1)?.onList).toBe(false);
	await expect(
		results(page).getByRole('button', { name: 'Remove filter: Not on my list' })
	).toBeVisible();
});

test('mode-specific filters are dropped when switching mode', async ({ page }) => {
	await mockLoggedIn(page);
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse?season=FALL&year=2026&genre=Action');
	await expect(
		results(page).getByRole('button', { name: 'Remove filter: Fall 2026' })
	).toBeVisible();

	await page.getByTestId('toggle-manga').click();
	await expect(page).toHaveURL('/browse?genre=Action');
	await expect(page.getByRole('heading', { name: 'Browse manga' })).toBeVisible();
});

test('mobile: the filter sheet edits a draft and applies it with a count', async ({ page }) => {
	const calls = await mockBrowse(page);
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/browse');

	await page.getByRole('button', { name: 'Filters' }).click();
	const sheet = page.getByRole('dialog', { name: 'Filters' });
	await expect(sheet).toBeVisible();
	await sheet.getByRole('button', { name: 'Fantasy', exact: true }).click();
	await sheet.getByRole('radio', { name: 'Score' }).click();
	// nothing applies until the button is pressed…
	await expect(page).toHaveURL('/browse');
	await sheet.getByRole('button', { name: 'Show 7 results' }).click();

	// …then it all applies at once
	await expect(page).toHaveURL('/browse?genre=Fantasy&sort=score');
	await expect(sheet).toHaveCount(0);
	await expect
		.poll(() => calls.at(-1))
		.toMatchObject({ genres: ['Fantasy'], sort: ['SCORE_DESC'] });
	await expect(page.getByRole('button', { name: 'Filters (1 on)' })).toBeVisible();
});

test('signed in, results show list state fetched for the titles on screen', async ({ page }) => {
	await mockLoggedIn(page);
	await mockBrowse(page, { onList: { 300001: 'PLANNING' } });
	await desktop(page);
	await gotoHydrated(page, '/browse');

	const card = results(page).getByRole('group', { name: 'Mock Browse 1', exact: true });
	await expect(card.getByText('Planning', { exact: true })).toBeVisible();
	await expect(
		results(page)
			.getByRole('group', { name: 'Mock Browse 2', exact: true })
			.getByText('Planning', { exact: true })
	).toHaveCount(0);
});

test('a See all list is named in the heading, on desktop and phones', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse?sort=trending');
	await expect(page.getByRole('heading', { level: 1, name: 'Trending anime' })).toBeVisible();
	await expect(page).toHaveTitle(/^Trending anime/);

	// back to plain Browse once the sort goes back to the default
	await gotoHydrated(page, '/browse');
	await expect(page.getByRole('heading', { level: 1, name: 'Browse anime' })).toBeVisible();

	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/browse?sort=trending');
	await expect(page.getByRole('heading', { level: 1, name: 'Trending anime' })).toBeVisible();
});

test('a genre tapped twice is excluded, and a third time cleared', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');
	const rail = page.getByRole('complementary', { name: 'Filters' });

	await rail.getByRole('button', { name: 'Drama', exact: true }).click();
	await expect(page).toHaveURL('/browse?genre=Drama');
	await rail.getByRole('button', { name: 'Drama', exact: true }).click();
	await expect(page).toHaveURL('/browse?not_genre=Drama');
	await expect.poll(() => calls.at(-1)?.notGenres).toEqual(['Drama']);
	await expect(rail.getByRole('button', { name: 'Drama, excluded' })).toHaveAttribute(
		'aria-pressed',
		'false'
	);
	await expect(
		results(page).getByRole('button', { name: 'Remove filter: Not Drama' })
	).toBeVisible();

	await rail.getByRole('button', { name: 'Drama, excluded' }).click();
	await expect(page).toHaveURL('/browse');
});

test('a tag can be excluded from its search', async ({ page }) => {
	const calls = await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');
	const rail = page.getByRole('complementary', { name: 'Filters' });

	await rail.getByRole('textbox', { name: 'Tags' }).fill('elf');
	await rail.getByRole('button', { name: 'Exclude tag Elf' }).click();
	await expect(page).toHaveURL('/browse?not_tag=Elf');
	await expect.poll(() => calls.at(-1)?.notTags).toEqual(['Elf']);
	await rail.getByRole('button', { name: 'Remove excluded tag Elf' }).click();
	await expect(page).toHaveURL('/browse');
});

test('a search also finds characters, staff, users and studios', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse?q=frieren');
	const people = results(page).getByTestId('search-people');

	const character = people.getByRole('region', { name: 'Characters' }).getByRole('link');
	await expect(character).toHaveAttribute('href', '/character/176754');
	// signed out, the English title it's known from
	await expect(character).toContainText("Frieren: Beyond Journey's End");
	await expect(
		people.getByRole('region', { name: 'Staff' }).getByRole('link', { name: /Atsumi Tanezaki/ })
	).toHaveAttribute('href', '/staff/95185');
	// a user opens their miruyo page, the name made safe for the address
	await expect(
		people.getByRole('region', { name: 'Users' }).getByRole('link', { name: 'frieren fan' })
	).toHaveAttribute('href', '/user/frieren%20fan');
	await expect(people.getByRole('link', { name: 'MADHOUSE' })).toHaveAttribute(
		'href',
		'/studio/11'
	);

	// titles come first: people follow the first rows of them
	const firstTitle = results(page).locator('a[href^="/title/"]').first();
	await expect(firstTitle).toBeVisible();
	const peopleBox = await people.elementHandle();
	expect(
		await firstTitle.evaluate(
			(a, box) => !!(a.compareDocumentPosition(box!) & Node.DOCUMENT_POSITION_FOLLOWING),
			peopleBox
		)
	).toBe(true);

	// nobody matches: no row at all
	await gotoHydrated(page, '/browse?q=zzz');
	await expect(results(page).getByTestId('search-people')).toHaveCount(0);
});

test('ready-made lists, and ranked lists number their results', async ({ page }) => {
	await mockBrowse(page);
	await desktop(page);
	await gotoHydrated(page, '/browse');
	const lists = page.getByRole('navigation', { name: 'Lists' }).first();

	await expect(lists.getByRole('link', { name: 'All-time popular' })).toHaveAttribute(
		'aria-current',
		'page'
	);
	await lists.getByRole('link', { name: 'Top rated' }).click();
	await expect(page).toHaveURL('/browse?sort=score');
	await expect(page.getByRole('heading', { level: 1, name: 'Top-rated anime' })).toBeVisible();
	await expect(results(page).getByText('#1', { exact: true })).toBeVisible();

	// a search is ordered by the match, so it isn't ranked
	await gotoHydrated(page, '/browse?q=mock&sort=score');
	await expect(results(page).getByText('#1', { exact: true })).toHaveCount(0);
});
