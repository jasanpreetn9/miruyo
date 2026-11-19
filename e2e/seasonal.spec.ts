import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import {
	mockLoggedIn,
	mockSeasonChart,
	type AniListCall,
	type MockSeasonTitle
} from './mock-auth.ts';

// A fixed "now" — Wednesday 7 Oct 2026 — so the season is Fall 2026.
const NOW = new Date('2026-10-07T12:00:00+09:00');
test.use({ timezoneId: 'Asia/Tokyo' });

const FALL: MockSeasonTitle[] = [
	{
		id: 800001,
		title: 'Apothecary Season 3',
		episodes: 12,
		airsIn: 18 * 3600 + 31 * 60 + 30,
		score: 85,
		rank: 1,
		sequelTo: 'Apothecary Season 2',
		genres: ['Drama', 'Mystery']
	},
	{ id: 800002, title: 'Welsh & Shedar', source: 'ORIGINAL', airsIn: 3 * 86400, score: 54 },
	{
		id: 800003,
		title: 'Big Movie',
		format: 'MOVIE',
		status: 'NOT_YET_RELEASED',
		score: null
	},
	{ id: 800004, title: 'Short One', format: 'TV_SHORT', airsIn: 3600 }
];
const LEFTOVERS: MockSeasonTitle[] = [
	{ id: 800010, title: 'Long Runner', episodes: 0, airsIn: 7200, nextEpisode: 152 }
];

async function open(page: Page, url = '/seasonal', width = 1440) {
	await page.clock.setFixedTime(NOW);
	const calls = await mockSeasonChart(
		page,
		{ 'FALL 2026': FALL, 'WINTER 2027': [{ id: 800020, title: 'Winter Show' }] },
		LEFTOVERS,
		NOW
	);
	await page.setViewportSize({ width, height: 1000 });
	await gotoHydrated(page, url);
	return calls;
}

const section = (page: Page, name: string) =>
	page.getByRole('region', { name: new RegExp(`^${name}`) });
const card = (page: Page, title: string) =>
	page.getByTestId('season-card').filter({ has: page.getByRole('heading', { name: title }) });

test('the season chart: AniChart’s sections and cards', async ({ page }) => {
	await open(page);
	await expect(page.getByRole('heading', { name: 'Fall 2026', level: 1 })).toBeVisible();
	await expect(
		page.getByText('4 titles premiering, 1 still airing from earlier seasons')
	).toBeVisible();

	const headings = page.getByRole('heading', { level: 2 });
	await expect(headings).toHaveText([/^TV/, /^TV Short/, /^Leftovers/, /^Movie/]);

	const apothecary = card(page, 'Apothecary Season 3');
	await expect(apothecary).toContainText('Ep 2 of 12 airing in');
	await expect(apothecary).toContainText('18 hours, 31 mins');
	await expect(apothecary).toContainText('Sequel to Apothecary Season 2');
	await expect(apothecary.getByLabel('Average score 85%')).toBeVisible();
	await expect(apothecary.getByLabel('Number 1 most popular this season')).toBeVisible();
	await expect(apothecary).toContainText('Drama');

	await expect(card(page, 'Welsh & Shedar')).toContainText('Source • Original');
	await expect(card(page, 'Big Movie')).toContainText('Premieres');
	await expect(section(page, 'Leftovers')).toContainText('Ep 152 airing in');
});

test('sort and filter', async ({ page }) => {
	await open(page);
	const tvCards = section(page, 'TV').first().getByTestId('season-card');
	await expect(tvCards.first()).toContainText('Apothecary Season 3');

	await page.getByRole('combobox', { name: /Sort/ }).selectOption('title');
	await expect(tvCards.first()).toContainText('Apothecary Season 3');
	await page.getByRole('combobox', { name: /Sort/ }).selectOption('airing');
	await expect(tvCards.first()).toContainText('Apothecary Season 3');

	await page.getByLabel('Filter this season').fill('welsh');
	await expect(page.getByTestId('season-card')).toHaveCount(1);
	await page.getByLabel('Filter this season').fill('nothing like this');
	await expect(page.getByText('Nothing in Fall 2026 matches')).toBeVisible();
});

test('season tabs, the Airing view, and old week links', async ({ page }) => {
	const calls = await open(page);
	const header = page.getByTestId('season-header');
	await expect(header.getByRole('link', { name: /Fall\s*2026/ })).toHaveAttribute(
		'aria-current',
		'page'
	);
	await header.getByRole('link', { name: /Winter\s*2027/ }).click();
	await expect(page).toHaveURL('/seasonal?season=winter&year=2027');
	await expect(card(page, 'Winter Show')).toBeVisible();
	expect(calls.at(-1)?.variables).toMatchObject({ season: 'WINTER', year: 2027 });

	await header.getByRole('link', { name: 'Airing' }).click();
	await expect(page).toHaveURL('/schedule');

	await gotoHydrated(page, '/seasonal?week=2026-10-12');
	await expect(page).toHaveURL('/schedule?week=2026-10-12');
});

test('a season without a chart opens this one; the tabs and arrows stop at the ends', async ({
	page
}) => {
	const calls = await open(page, '/seasonal?season=winter&year=2367');
	const header = page.getByTestId('season-header');
	await expect(header.getByRole('link', { name: /Fall\s*2026/ })).toHaveAttribute(
		'aria-current',
		'page'
	);
	expect(calls.every((c) => c.variables.year !== 2367)).toBe(true);

	// two years out is the last chart
	await gotoHydrated(page, '/seasonal?season=fall&year=2028');
	await expect(header.getByRole('link', { name: /Fall\s*2028/ })).toHaveAttribute(
		'aria-current',
		'page'
	);
	await expect(header.getByRole('link', { name: /2029/ })).toHaveCount(0);
	await expect(header.getByRole('link', { name: 'Later season' })).toHaveCount(0);
	await expect(header.getByRole('link', { name: 'Earlier season' })).toHaveAttribute(
		'href',
		'/seasonal?season=summer&year=2028'
	);

	await gotoHydrated(page, '/seasonal?season=winter&year=1940');
	await expect(header.getByRole('link', { name: 'Earlier season' })).toHaveCount(0);
	await expect(header.getByRole('link', { name: 'Later season' })).toBeVisible();
});

test('signed out, + leads to log in', async ({ page }) => {
	await open(page);
	await expect(
		card(page, 'Welsh & Shedar').getByRole('link', { name: /Log in to add Welsh & Shedar/ })
	).toHaveAttribute('href', '/login');
});

test('signed in, + opens the status menu and saves', async ({ page }) => {
	const calls: AniListCall[] = await mockLoggedIn(page);
	await open(page);
	const welsh = card(page, 'Welsh & Shedar');
	await welsh.getByRole('button', { name: 'Add Welsh & Shedar to list' }).click();
	await page.getByRole('menuitemradio', { name: /Planning/ }).click();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 800002, status: 'PLANNING' });
	await expect(welsh.getByRole('button', { name: /Change list status/ })).toContainText('Planning');
});

test('arriving in manga mode switches to anime', async ({ page }) => {
	await page.addInitScript(() => localStorage.setItem('miruyo_mode', 'manga'));
	await open(page);
	await expect(page.getByRole('heading', { name: 'Fall 2026', level: 1 })).toBeVisible();
	await expect(page.getByTestId('toggle-anime')).toHaveAttribute('aria-pressed', 'true');
});

test('mobile: Seasonal is a tab', async ({ page }) => {
	await mockLoggedIn(page);
	await open(page, '/', 390);
	await page.locator('nav.fixed').getByRole('link', { name: 'Seasonal' }).click();
	await expect(page).toHaveURL('/seasonal');
	await expect(page.getByTestId('season-card').first()).toBeVisible();
});
