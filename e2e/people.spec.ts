import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import { mockDetail, mockLoggedIn, mockPeople } from './helpers/mock-auth.ts';

const desktop = (page: Page) => page.setViewportSize({ width: 1440, height: 900 });

test('a staff page shows who they are, their roles, and loads more', async ({ page }) => {
	const calls = await mockPeople(page);
	await desktop(page);
	await gotoHydrated(page, '/staff/21');

	await expect(page.getByRole('heading', { level: 1, name: 'Mock Voice' })).toBeVisible();
	const facts = page.getByRole('complementary');
	await expect(facts.getByText('Sep 27, 1990')).toBeVisible();
	// the description's leading "__Height:__" line is a fact, not text
	await expect(facts.getByText('157 cm')).toBeVisible();
	// its spoiler stays hidden until asked for
	await expect(page.getByText('Secret twist.')).toHaveCount(0);
	await page.getByRole('button', { name: 'Spoiler', exact: true }).click();
	await expect(page.getByText('Secret twist.')).toBeVisible();

	const roles = page.getByTestId('voice-roles');
	await expect(roles.getByRole('link', { name: /Popular Show/ })).toHaveAttribute(
		'href',
		'/title/300110'
	);
	await expect(roles.getByRole('link', { name: /Popular Hero/ })).toHaveAttribute(
		'href',
		'/character/400101'
	);
	await expect(page.getByTestId('credits').getByText('Theme Song Performance')).toBeVisible();

	await roles.getByRole('button', { name: 'Load more' }).click();
	await expect(roles.getByRole('link', { name: /More Show/ })).toBeVisible();
	await expect(roles.getByRole('link', { name: /Popular Show/ })).toBeVisible();
	await expect(roles.getByRole('button', { name: 'Load more' })).toHaveCount(0);
	expect(
		calls.some((c) => c.query.includes('query StaffVoiceRoles') && c.variables.page === 2)
	).toBe(true);
});

test('the sort reloads only the roles, and lives in the URL', async ({ page }) => {
	const calls = await mockPeople(page);
	await desktop(page);
	await gotoHydrated(page, '/staff/21');

	const roles = page.getByTestId('voice-roles');
	await roles.getByRole('button', { name: 'Newest' }).click();
	await expect(page).toHaveURL(/\/staff\/21\?sort=newest$/);
	await expect(roles.getByRole('link', { name: /Newest Show/ })).toBeVisible();
	await expect(roles.getByRole('button', { name: 'Newest' })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
	// the person was fetched once; only their roles came again
	expect(calls.filter((c) => c.query.includes('query StaffPage'))).toHaveLength(1);
});

test('a character page lists their titles, with voices by language', async ({ page }) => {
	await mockPeople(page);
	await desktop(page);
	await gotoHydrated(page, '/character/11');

	await expect(page.getByRole('heading', { level: 1, name: 'Mock Hero' })).toBeVisible();
	await expect(page.getByText('The Hero', { exact: true })).toBeVisible();
	await expect(page.getByText('Secret Name')).toHaveCount(0);
	await page.getByRole('button', { name: 'Show 1 spoiler name' }).click();
	await expect(page.getByText('Secret Name')).toBeVisible();
	// a link to an AniList title in the bio opens it in miruyo
	await expect(page.getByRole('link', { name: 'Mock Title', exact: true }).first()).toHaveAttribute(
		'href',
		'/title/300100'
	);

	const appearances = page.getByTestId('appearances');
	await expect(appearances.getByRole('link', { name: /Mock Voice/ })).toHaveAttribute(
		'href',
		'/staff/21'
	);
	await appearances.getByLabel('Voices').selectOption('English');
	await expect(appearances.getByRole('link', { name: /Mock Dub/ })).toHaveAttribute(
		'href',
		'/staff/22'
	);
	await expect(appearances.getByRole('link', { name: /Mock Voice/ })).toHaveCount(0);
});

test('the title page opens its characters and voice actors', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('tab', { name: 'Characters & Staff' }).click();
	const panel = page.getByRole('tabpanel');
	await expect(panel.getByRole('link', { name: /Mock Hero/ })).toHaveAttribute(
		'href',
		'/character/11'
	);
	await expect(panel.getByRole('link', { name: /Mock Voice/ })).toHaveAttribute(
		'href',
		'/staff/21'
	);
});

test('signed in, a favourite toggles on AniList and roles show their list status', async ({
	page
}) => {
	await mockLoggedIn(page);
	const calls = await mockPeople(page, { onList: { 300110: 'CURRENT' } });
	await desktop(page);
	await gotoHydrated(page, '/staff/21');

	await expect(page.getByTestId('voice-roles').getByText('Watching')).toBeVisible();
	await page
		.getByRole('complementary')
		.getByRole('button', { name: /Add to favourites/ })
		.click();
	await expect(
		page.getByRole('complementary').getByRole('button', { name: /Favourite/ })
	).toHaveAttribute('aria-pressed', 'true');
	const toggle = calls.find((c) => c.query.includes('mutation ToggleFavourite'));
	expect(toggle?.variables).toEqual({ staffId: 21 });
});

test('someone AniList doesn’t know shows not found', async ({ page }) => {
	await mockPeople(page);
	await gotoHydrated(page, '/staff/999');
	await expect(page.getByRole('heading', { name: "This person isn't on AniList" })).toBeVisible();
	await gotoHydrated(page, '/character/999');
	await expect(
		page.getByRole('heading', { name: "This character isn't on AniList" })
	).toBeVisible();
});

test('a studio page lists its titles, marks co-productions, and loads more', async ({ page }) => {
	const calls = await mockPeople(page);
	await desktop(page);
	await gotoHydrated(page, '/studio/11');

	const header = page.getByTestId('studio-header');
	await expect(header.getByRole('heading', { level: 1, name: 'Mock Studio' })).toBeVisible();
	await expect(header.getByText('Animation studio')).toBeVisible();
	await expect(header.getByRole('link', { name: /View on AniList/ })).toHaveAttribute(
		'href',
		'https://anilist.co/studio/11'
	);

	const titles = page.getByTestId('studio-titles');
	await expect(titles.getByRole('link', { name: /Popular Studio Show/ })).toHaveAttribute(
		'href',
		'/title/300301'
	);
	// a title it only helped on says so
	await expect(titles.getByText('Producer')).toBeVisible();

	await titles.getByRole('button', { name: 'Load more' }).click();
	await expect(titles.getByRole('link', { name: /More Studio Show/ })).toBeVisible();
	await expect(titles.getByRole('button', { name: 'Load more' })).toHaveCount(0);
	expect(calls.some((c) => c.query.includes('query StudioMedia') && c.variables.page === 2)).toBe(
		true
	);

	// the sort reloads only the titles, and lives in the URL
	await titles.getByRole('button', { name: 'Newest' }).click();
	await expect(page).toHaveURL(/\/studio\/11\?sort=newest$/);
	await expect(titles.getByRole('link', { name: /Newest Studio Show/ })).toBeVisible();
	expect(calls.filter((c) => c.query.includes('query StudioPage'))).toHaveLength(1);
});

test('signed in, a studio can be favourited', async ({ page }) => {
	await mockLoggedIn(page);
	const calls = await mockPeople(page);
	await desktop(page);
	await gotoHydrated(page, '/studio/11');

	const button = page.getByRole('button', { name: /Add to favourites/ });
	await button.click();
	await expect(page.getByRole('button', { name: /^Favourite/ })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
	expect(
		calls.some((c) => c.query.includes('mutation ToggleFavourite') && c.variables.studioId === 11)
	).toBe(true);
});

test("a studio AniList doesn't know says so", async ({ page }) => {
	await mockPeople(page);
	await gotoHydrated(page, '/studio/999');
	await expect(page.getByRole('heading', { name: "This studio isn't on AniList" })).toBeVisible();
});
