import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockLoggedIn, mockUser } from './helpers/mock-auth.ts';

const desktop = (page: Page) => page.setViewportSize({ width: 1440, height: 900 });

test('a user page opens on their overview, with tabs for their lists', async ({ page }) => {
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/rin');

	await expect(page.getByRole('heading', { level: 1, name: 'rin' })).toBeVisible();
	// the facts card, in the left column as on a staff page
	await expect(page.locator('dl').first()).toContainText(/Member since\s*May 2016/);
	const tabs = page.getByRole('navigation', { name: 'rin’s profile' });
	await expect(tabs.getByRole('link', { name: 'Overview' })).toHaveAttribute(
		'aria-current',
		'page'
	);
	for (const [label, href] of [
		['Anime list', '/user/rin/animelist'],
		['Manga list', '/user/rin/mangalist']
	]) {
		await expect(tabs.getByRole('link', { name: label })).toHaveAttribute('href', href);
	}

	// the bio, with its spoiler hidden
	await expect(page.getByText('everything')).toBeVisible();
	await expect(page.getByText('Even the sequels.')).toHaveCount(0);
	// favourites, then their Stats
	await expect(page.getByRole('heading', { name: 'Favourite anime' })).toBeVisible();
	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();
	await expect(page.getByTestId('stat-cards')).toContainText(/Total anime\s*3/);
	// the facts card agrees, and leaves out the 18+ title this viewer doesn't see
	await expect(page.locator('dl').first()).toContainText(/Total anime\s*3/);
	await page
		.getByRole('navigation', { name: 'rin’s profile' })
		.getByRole('link', { name: 'Anime list' })
		.click();
	await expect(page.getByTestId('user-list').getByRole('link', { name: /All\s*3/ })).toBeVisible();
	await expect(page.getByText('Grown-up Show')).toHaveCount(0);
});

test('their anime list: every status, or one; best first, sortable, read-only', async ({
	page
}) => {
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/rin');

	await page
		.getByRole('navigation', { name: 'rin’s profile' })
		.getByRole('link', { name: 'Anime list' })
		.click();
	await expect(page).toHaveURL(/\/user\/rin\/animelist$/);
	const list = page.getByTestId('user-list');
	// it opens on every status, each in its own panel
	await expect(list.getByRole('region', { name: /Watching/ })).toContainText('Ongoing Show');
	await expect(
		list.getByRole('region', { name: /Completed/ }).getByTestId('user-list-row')
	).toHaveCount(2);

	// the statuses, format and sort in a toolbar above the list, as on My List
	await list
		.getByRole('navigation', { name: /list by status/ })
		.getByRole('link', { name: /Completed\s*2/ })
		.click();
	await expect(page).toHaveURL(/\?status=completed$/);
	await expect(list.getByRole('region', { name: /Watching/ })).toHaveCount(0);
	const rows = list.getByTestId('user-list-row');
	await expect(rows.first()).toContainText('Best Show');
	await expect(rows.first()).toContainText('9.5');
	await expect(rows.nth(1)).toContainText('Good Show');

	await list.getByLabel('Sort').selectOption('title');
	await expect(page).toHaveURL(/status=completed&sort=title/);
	await expect(rows.first()).toContainText('Best Show');
	await list.getByRole('searchbox', { name: 'Filter the list' }).fill('good');
	await expect(rows).toHaveCount(1);
	// nothing to edit on someone else's list
	await expect(list.getByRole('button', { name: /Add one/ })).toHaveCount(0);
});

test("their list filters by AniList's genre, country and year", async ({ page }) => {
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/rin/animelist');
	const list = page.getByTestId('user-list');
	const rows = list.getByTestId('user-list-row');
	await expect(rows).toHaveCount(3);

	// each offers what's on the list, by name
	await expect(list.getByLabel('Country').locator('option')).toHaveText([
		'Country',
		'Japan',
		'South Korea'
	]);
	await expect(list.getByLabel('Year').locator('option')).toHaveText(['Year', '2026', '2019']);

	await list.getByLabel('Genre').selectOption('Drama');
	await expect(page).toHaveURL(/\?genre=Drama$/);
	await expect(rows).toHaveCount(1);
	await expect(rows.first()).toContainText('Good Show');
	// panels with nothing left go
	await expect(list.getByRole('region', { name: /Watching/ })).toHaveCount(0);

	await list.getByLabel('Genre').selectOption('');
	await list.getByLabel('Country').selectOption('JP');
	await expect(rows).toHaveCount(2);
	await list.getByLabel('Year').selectOption('2019');
	await expect(page).toHaveURL(/country=JP&year=2019/);
	await expect(list.getByText('Nothing matches.')).toBeVisible();

	// the URL keeps them, and the picked year stays an option
	await gotoHydrated(page, '/user/rin/animelist?year=2019');
	await expect(rows).toHaveCount(1);
	await expect(list.getByLabel('Year')).toHaveValue('2019');
});

test('favourites and stats are on the overview; their old tabs forward there', async ({ page }) => {
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/rin/favourites');
	await expect(page).toHaveURL(/\/user\/rin$/);
	await expect(page.getByRole('heading', { name: 'Favourite characters' })).toBeVisible();
	await expect(page.getByRole('link', { name: 'Their Character' })).toHaveAttribute(
		'href',
		'/character/500003'
	);

	await expect(page.getByRole('heading', { name: 'Stats' })).toBeVisible();
	await expect(page.getByTestId('stat-cards')).toBeVisible();
	// someone else's stats don't ask you to rate their titles
	await expect(page.getByTestId('rate-prompt')).toHaveCount(0);
});

test('a private list says so on its tabs', async ({ page }) => {
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/hidden/animelist');
	await expect(page.getByTestId('private-list')).toContainText('hidden keeps their list private');
	await page
		.getByRole('navigation', { name: 'hidden’s profile' })
		.getByRole('link', { name: 'Overview' })
		.click();
	await expect(page.getByTestId('private-list')).toBeVisible();
});

test('someone AniList doesn’t know shows not found', async ({ page }) => {
	await mockUser(page);
	await gotoHydrated(page, '/user/nobody');
	await expect(
		page.getByRole('heading', { name: 'There’s no one called nobody on AniList' })
	).toBeVisible();
});

test('signed in, you can follow them', async ({ page }) => {
	await mockLoggedIn(page);
	const calls = await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/user/rin');

	await expect(page.getByText('Follows you')).toBeVisible();
	await page.getByRole('button', { name: 'Follow' }).click();
	await expect(page.getByRole('button', { name: 'Following' })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
	expect(calls.find((c) => c.query.includes('mutation ToggleFollow'))?.variables).toEqual({
		userId: 700
	});
});

test('My List’s Share list opens your list as others see it', async ({ page }) => {
	await mockLoggedIn(page);
	await mockUser(page);
	await desktop(page);
	await gotoHydrated(page, '/list');
	await expect(page.getByRole('link', { name: 'Share list' })).toHaveAttribute(
		'href',
		'/user/haruka_k/animelist'
	);
});
