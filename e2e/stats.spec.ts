import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockListCollection, mockLoggedIn, type MockListEntry } from './mock-auth.ts';

// Your profile is your own user page (/user/haruka_k): favourites and Stats,
// as anyone's, but with Settings in place of Follow and no list tabs (your
// list is My List). Here, the parts that are yours (your whole list, your
// score format, Settings, your list links opening My List). Other people's
// pages: user.spec.ts.

const ENTRIES: MockListEntry[] = [
	{ id: 500001, title: 'Frieren', status: 'COMPLETED', progress: 28, episodes: 28, score: 9.5 },
	{ id: 500002, title: 'Mob Psycho', status: 'COMPLETED', progress: 12, episodes: 12, score: 8 },
	{ id: 500003, title: 'Dandadan Movie', status: 'CURRENT', progress: 0, format: 'MOVIE' },
	{ id: 500004, title: 'Planned One', status: 'PLANNING', progress: 0 }
];

/** AniList's activityHistory: today and yesterday were active. */
async function mockActivity(page: Page) {
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string };
		if (!body.query.includes('query ActivityHistory')) return route.fallback();
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		const day = (ago: number) => today.getTime() / 1000 - ago * 86400;
		await route.fulfill({
			status: 200,
			contentType: 'application/json',
			body: JSON.stringify({
				data: {
					User: {
						id: 1,
						stats: {
							activityHistory: [
								{ date: day(1), amount: 3, level: 1 },
								{ date: day(0), amount: 5, level: 2 }
							]
						}
					}
				}
			})
		});
	});
}

async function openProfile(page: Page, url = '/profile', width = 1440) {
	await mockLoggedIn(page);
	await mockListCollection(page, ENTRIES);
	await mockActivity(page);
	await page.setViewportSize({ width, height: 900 });
	await gotoHydrated(page, url);
}

const tabs = (page: Page) => page.getByRole('navigation', { name: 'haruka_k’s profile' });

test('signed out, the profile asks you to log in', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/profile');
	await expect(page.getByRole('heading', { name: 'Your profile lives on AniList' })).toBeVisible();
});

test('your profile is your own page: Settings in the left column, favourites and Stats', async ({
	page
}) => {
	await openProfile(page);
	await expect(page).toHaveURL(/\/user\/haruka_k$/);
	await expect(page.getByRole('heading', { level: 1, name: 'haruka_k' })).toBeVisible();
	// laid out as a staff page: the facts card, then Settings where others have Follow
	const facts = page.locator('dl').first();
	await expect(facts).toContainText(/Member since\s*March 2019/);
	// the same numbers as the Stats cards
	await expect(facts).toContainText(/Total anime\s*4/);
	await expect(page.locator('a[href="/settings"]:visible')).toHaveText(/Settings/);
	await expect(page.getByRole('button', { name: /Follow/ })).toHaveCount(0);
	await expect(page.getByRole('link', { name: /View on AniList/ }).first()).toHaveAttribute(
		'href',
		'https://anilist.co/user/haruka_k'
	);
	// the nav's Profile is this page
	await expect(page.getByRole('banner').getByRole('link', { name: 'Profile' })).toHaveAttribute(
		'href',
		'/user/haruka_k'
	);

	// a favourite on your list shows its status, as posters elsewhere do
	await expect(page.getByRole('heading', { name: 'Favourite anime' })).toBeVisible();
	await expect(page.getByRole('group', { name: 'Favourite Anime' })).toContainText(/Watching/);

	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();
	await expect(page.getByRole('link', { name: /Favourite Character/ })).toHaveAttribute(
		'href',
		'/character/500003'
	);
	await expect(page.getByRole('link', { name: 'Madhouse' })).toBeVisible();
});

test('a profile that fails to load says so, with a retry', async ({ page }) => {
	await mockLoggedIn(page);
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (!query.includes('query UserProfile')) return route.fallback();
		await route.fulfill({ json: { errors: [{ message: 'Mock validation error', status: 400 }] } });
	});
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/profile');
	await expect(page.getByText("Couldn't load this profile")).toBeVisible();
	await expect(page.getByRole('button', { name: /Retry/ })).toBeVisible();
});

test('if only the favourite titles fail, the rest of the profile still shows', async ({ page }) => {
	await openProfile(page);
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (!query.includes('query FavouriteMedia')) return route.fallback();
		await route.fulfill({
			status: 500,
			json: { errors: [{ message: 'Internal Server Error', status: 500 }] }
		});
	});
	await gotoHydrated(page, '/user/haruka_k');
	await expect(page.getByText("Couldn't load your favourite anime and manga")).toBeVisible();
	await expect(page.locator('dl').first()).toContainText(/Member since\s*March 2019/);
	await expect(page.getByRole('link', { name: /Favourite Character/ })).toBeVisible();
});

test('old /stats and /profile?range= links open your Stats', async ({ page }) => {
	await openProfile(page, '/stats?range=12m');
	await expect(page).toHaveURL(/\/user\/haruka_k\?range=12m$/);
	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();

	await gotoHydrated(page, '/user/haruka_k/stats?range=6m');
	await expect(page).toHaveURL(/\/user\/haruka_k\?range=6m$/);
	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();
});

test('your Stats come from your whole list, in your score format', async ({ page }) => {
	await openProfile(page);
	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();

	const cards = page.getByTestId('stat-cards');
	await expect(cards.getByText('Total anime')).toBeVisible();
	await expect(cards).toContainText('4');
	await expect(cards).toContainText(/Episodes watched\s*40/);
	await expect(cards).toContainText(/Mean score\s*8.8/);

	await expect(page.getByText('Mean 8.8 · σ 0.8')).toBeVisible();
	await expect(page.getByRole('listitem', { name: '1 title scored 10' })).toBeVisible();
	await expect(page.getByRole('listitem', { name: '1 title scored 8' })).toBeVisible();

	const format = page.locator('section').filter({ hasText: 'Format' });
	await expect(format.getByText('TV')).toBeVisible();
	await expect(format.getByText('75%')).toBeVisible();
	await expect(format.getByText('Completed 2')).toBeVisible();

	await expect(page.getByRole('heading', { name: 'Top genres' })).toBeVisible();
	await expect(page.getByTestId('heatmap')).toHaveAttribute(
		'aria-label',
		'8 list updates in the last 26 weeks'
	);
});

test('manga swaps the units; the range lives in the URL', async ({ page }) => {
	await openProfile(page, '/user/haruka_k');
	await page.getByRole('radio', { name: 'Manga' }).click();
	await expect(page.getByTestId('stat-cards')).toContainText('Chapters read');
	await expect(page.getByTestId('stat-cards')).toContainText('Volumes read');

	await page.getByLabel('Time range').selectOption('12m');
	await expect(page).toHaveURL(/\/user\/haruka_k\?range=12m$/);
});

test('your own profile has no list tabs: your list is My List', async ({ page }) => {
	await openProfile(page);
	await expect(page.getByRole('heading', { level: 1, name: 'haruka_k' })).toBeVisible();
	await expect(page.getByRole('heading', { level: 2, name: 'Stats' })).toBeVisible();
	await expect(tabs(page)).toHaveCount(0);

	// a link to your list (one you shared) opens My List, on the same status
	await gotoHydrated(page, '/user/haruka_k/animelist?status=completed');
	await expect(page).toHaveURL(/\/list\?tab=completed$/);
	await expect(page.getByRole('tab', { name: /Completed 2/ })).toHaveAttribute(
		'aria-selected',
		'true'
	);
});

test('mobile: the Profile tab opens your page', async ({ page }) => {
	await openProfile(page, '/', 390);
	await page.getByRole('link', { name: 'Profile' }).click();
	await expect(page).toHaveURL(/\/user\/haruka_k$/);
	await expect(page.getByTestId('stat-cards')).toContainText(/Total anime\s*4/);
});
