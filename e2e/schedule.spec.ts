import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import {
	mockListCollection,
	mockLoggedIn,
	mockSeasonal,
	type MockAiring
} from './helpers/mock-auth.ts';

// A fixed "now" — Wednesday 7 Oct 2026, 18:20 in Tokyo — so the week, today,
// the NOW line and countdowns are the same on every run.
test.use({ timezoneId: 'Asia/Tokyo' });
const NOW = new Date('2026-10-07T18:20:00+09:00');
const tokyo = (iso: string) => Math.floor(new Date(`${iso}+09:00`).getTime() / 1000);

const AIRINGS: MockAiring[] = [
	{
		id: 1,
		mediaId: 600001,
		title: 'Monday Show',
		episode: 3,
		airingAt: tokyo('2026-10-05T23:00:00')
	},
	{
		id: 2,
		mediaId: 600002,
		title: 'Aired Today',
		episode: 4,
		airingAt: tokyo('2026-10-07T12:00:00')
	},
	{
		id: 3,
		mediaId: 600003,
		title: 'Later Today',
		episode: 9,
		airingAt: tokyo('2026-10-07T23:00:00')
	},
	{
		id: 4,
		mediaId: 600004,
		title: 'Friday Show',
		episode: 7,
		airingAt: tokyo('2026-10-09T23:30:00')
	},
	{
		id: 5,
		mediaId: 600005,
		title: 'Next Week Show',
		episode: 2,
		airingAt: tokyo('2026-10-13T20:00:00')
	},
	{
		id: 6,
		mediaId: 600006,
		title: 'Winter Premiere',
		episode: 1,
		airingAt: tokyo('2026-01-02T22:00:00')
	}
];

async function open(page: Page, url = '/schedule') {
	await page.clock.setFixedTime(NOW);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, url);
}

const column = (page: Page, name: string) =>
	page.getByTestId('week-grid').getByRole('region', { name: new RegExp(`^${name},`) });

test('the week, AniChart-style: today first, slots by time, and what airs next', async ({
	page
}) => {
	await mockSeasonal(page, AIRINGS);
	await open(page);

	await expect(page.getByTestId('week-label')).toHaveText('Fall 2026 · week of Oct 5');
	await expect(page.getByText(/Times in .*UTC\+9/)).toBeVisible();

	const today = column(page, 'Today');
	await expect(today.getByTestId('airing-slot')).toHaveCount(2);
	await expect(today.getByTestId('airing-slot').first()).toContainText('Ep 4 aired at 12:00');
	const later = today.getByTestId('airing-slot').last();
	await expect(later).toContainText('Ep 9 airing at 23:00');
	await expect(later).toContainText('in 4h 40m');
	await expect(later.getByText('Airing next')).toBeVisible();
	await expect(page.getByText('Airing next')).toHaveCount(1);

	await expect(column(page, 'Fri').getByTestId('airing-slot')).toContainText(
		'Ep 7 airing at 23:30'
	);
	// today first; Monday has already passed, so it folds under Earlier this week
	const sections = page.getByTestId('week-grid').getByRole('region');
	await expect(sections).toHaveCount(2);
	await expect(sections.first()).toHaveAccessibleName(/^Today,/);
	await page.getByText('Earlier this week').click();
	await expect(sections).toHaveCount(3);
	await expect(sections.last()).toHaveAccessibleName(/^Mon,/);
	await expect(page.getByText('Next Week Show')).toHaveCount(0);
});

test('weeks are in the URL; the seasons go to the season chart', async ({ page }) => {
	await mockSeasonal(page, AIRINGS);
	await open(page);

	await page.getByRole('button', { name: 'Next week' }).click();
	await expect(page).toHaveURL('/schedule?week=2026-10-12');
	await expect(page.getByTestId('week-label')).toHaveText('Fall 2026 · week of Oct 12');
	await expect(page.getByText('Next Week Show')).toBeVisible();
	await expect(page.getByRole('region', { name: /^Today,/ })).toHaveCount(0);

	await page.getByRole('button', { name: 'Back to this week' }).click();
	await expect(page).toHaveURL('/schedule');

	const header = page.getByTestId('season-header');
	await expect(header.getByRole('link', { name: 'Airing' })).toHaveAttribute(
		'aria-current',
		'page'
	);
	await expect(header.getByRole('link', { name: /Winter\s*2027/ })).toHaveAttribute(
		'href',
		'/seasonal?season=winter&year=2027'
	);
});

test('signed in, your shows glow, +1 once out, and "My list only"', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await mockSeasonal(page, AIRINGS, { onList: { 600002: ['CURRENT', 3], 600003: ['CURRENT', 8] } });
	await open(page);

	const today = column(page, 'Today');
	const aired = today.getByTestId('airing-slot').filter({ hasText: 'Aired Today' });
	await expect(aired.getByText('3/12')).toBeVisible();
	await aired.getByRole('button', { name: /Add one episode/ }).click();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 600002, progress: 4 });
	await expect(aired.getByRole('button', { name: /Add one episode/ })).toHaveCount(0);

	// not out yet: no +1
	await expect(
		today.getByTestId('airing-slot').filter({ hasText: 'Later Today' }).getByRole('button')
	).toHaveCount(0);

	await page.getByRole('switch', { name: 'My list only' }).click();
	await expect(page.getByTestId('week-grid').getByTestId('airing-slot')).toHaveCount(2);
	// days with nothing of yours drop out
	await expect(page.getByTestId('week-grid').getByRole('region')).toHaveCount(1);
});

test('mobile: the same day sections, stacked', async ({ page }) => {
	await mockSeasonal(page, AIRINGS);
	await page.clock.setFixedTime(NOW);
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/schedule');

	await expect(column(page, 'Today').getByTestId('airing-slot')).toHaveCount(2);
	await expect(column(page, 'Fri').getByText('Friday Show')).toBeVisible();
	await expect(page.getByTestId('week-grid').getByRole('region').first()).toHaveAccessibleName(
		/^Today,/
	);
});

test('manga: your releasing series first, then newly serialized', async ({ page }) => {
	await mockLoggedIn(page);
	await mockSeasonal(page, []);
	await mockListCollection(page, [
		{ id: 610001, title: 'Reading Releasing', status: 'CURRENT', progress: 40 },
		{ id: 610002, title: 'Planned Manga', status: 'PLANNING', progress: 0 }
	]);
	await page.addInitScript(() => localStorage.setItem('miruyo_mode', 'manga'));
	await open(page);

	await expect(page.getByRole('heading', { name: 'New releases' })).toBeVisible();
	await expect(page.getByTestId('your-series-summary')).toHaveText(
		"1 series you're reading is still releasing"
	);
	const rows = page.getByTestId('manga-row');
	const yours = rows.filter({ hasText: 'Reading Releasing' });
	await expect(yours.getByRole('button', { name: /Add one chapter/ })).toBeVisible();
	await expect(rows.filter({ hasText: 'Planned Manga' })).toHaveCount(0);
	const fresh = page
		.getByTestId('new-series')
		.getByTestId('manga-row')
		.filter({ hasText: 'Mock New Manga' });
	await fresh.getByRole('button', { name: 'Plan Mock New Manga' }).click();
	await expect(page.getByTestId('toast')).toContainText('Added Mock New Manga to Planning');
});
