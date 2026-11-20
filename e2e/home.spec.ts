import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import {
	mockExpiredToken,
	mockForYou,
	mockListCollection,
	mockLoggedIn,
	mockLoggedInEmpty,
	mockPublicTrending,
	mockRateLimitedHome
} from './helpers/mock-auth.ts';

test('home renders — desktop', async ({ page }) => {
	await mockPublicTrending(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	await page.screenshot({ path: 'e2e/screenshots/home-desktop.png', fullPage: true });
});

test('home renders — mobile', async ({ page }) => {
	await mockPublicTrending(page);
	await page.setViewportSize({ width: 390, height: 844 });
	await page.goto('/');
	await page.screenshot({ path: 'e2e/screenshots/home-mobile.png', fullPage: true });
});

test('home shows the sign-in hero and live public trending when logged out', async ({ page }) => {
	await mockPublicTrending(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');
	await expect(page.getByText('Every episode. Every chapter. One list.')).toBeVisible();
	await expect(page.getByRole('link', { name: 'Log in with AniList' }).first()).toBeVisible();
	await expect(page.getByText('Mock Public Trending One').last()).toBeVisible();
	// signed out there's no account preference: English, not romaji or userPreferred
	await expect(page.getByText('Mock Public Romaji')).toHaveCount(0);
	await expect(page.getByText('Mock Public Preferred')).toHaveCount(0);
});

test('signed out, Home has the same public rows as signed in', async ({ page }) => {
	await mockPublicTrending(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');
	await expect(page.getByRole('heading', { name: 'Trending now' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Popular this season' })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Upcoming' })).toBeVisible();
	await expect(page.getByText('Mock Popular One').last()).toBeVisible();

	// list actions send you to sign in
	await page.getByRole('button', { name: 'Plan Mock Upcoming One' }).click();
	await expect(page).toHaveURL(/\/login$/);
});

test("signed out on a phone, Trending's first covers load first; the page has one main", async ({
	page
}) => {
	await mockPublicTrending(page, { covers: true });
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/');
	await expect(page.getByRole('main')).toHaveCount(1);

	// the row: the heading's header, then the row around it
	const row = page.getByRole('heading', { name: 'Trending now' }).locator('xpath=../..');
	// the phone row's first cover loads first; the hidden desktop row's waits
	const phone = row.locator('.lg\\:hidden img');
	const desktop = row.locator('.lg\\:grid img');
	await expect(phone.first()).toHaveAttribute('fetchpriority', 'high');
	await expect(phone.first()).toHaveAttribute('loading', 'eager');
	await expect(desktop.first()).toHaveAttribute('loading', 'lazy');
	await expect(desktop.first()).toHaveAttribute('fetchpriority', 'auto');
});

const continueRow = (page: Page, name: string) =>
	page.getByTestId('continue-row').filter({ hasText: name });

test("signed in, titles follow the viewer's AniList title preference", async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(continueRow(page, 'Mock Continue Anime')).toBeVisible();
	await expect(page.getByText('Mock Continue Romaji')).toHaveCount(0);
	await expect(page.getByText('Mock Continue English')).toHaveCount(0);
});

test('a rate-limited feed counts down and retries on its own', async ({ page }) => {
	await mockRateLimitedHome(page, 1, 2);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	// generous timeouts: the first pages compile on a fresh dev server
	await expect(page.getByText('AniList is busy right now')).toBeVisible({ timeout: 10_000 });
	await expect(page.getByTestId('retry-countdown')).toHaveText(/0:0[12]/);
	await expect(continueRow(page, 'Mock Continue Anime')).toBeVisible({ timeout: 10_000 });
});

test('an expired token signs out and says why', async ({ page }) => {
	await mockExpiredToken(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(page.getByText('AniList signed you out')).toBeVisible();
	await expect(page.getByText('Every episode. Every chapter. One list.')).toBeVisible();
	expect(await page.evaluate(() => localStorage.getItem('anilist_token'))).toBeNull();

	await page.getByRole('button', { name: 'Dismiss' }).click();
	await expect(page.getByText('AniList signed you out')).toHaveCount(0);
});

test('home fetches and shows live AniList data when logged in', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	// tracking: everything in progress is in Continue
	await expect(page.getByRole('heading', { name: 'Continue watching' })).toBeVisible();
	await expect(continueRow(page, 'Mock Continue Anime')).toBeVisible();
	// recommending: no For You picks yet, so the hero shows the season's most popular
	await expect(page.getByRole('region', { name: 'Picked for you' })).toContainText(
		'Mock Popular One'
	);
	await expect(page.getByText('Trending now')).toBeVisible();
	await expect(page.getByText('Mock Trending One').last()).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Upcoming' })).toBeVisible();
});

test('an empty list gets the quick-pick, which adds picks as Completed', async ({ page }) => {
	const calls = await mockLoggedInEmpty(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const card = page.getByTestId('quick-pick');
	await expect(card.getByText('Your anime list is empty.', { exact: false })).toBeVisible();
	const add = card.getByRole('button', { name: 'Pick at least one' });
	await expect(add).toBeDisabled();

	await card.getByRole('button', { name: 'Mock Trending One' }).click();
	await card.getByRole('button', { name: 'Mock Trending Two' }).click();
	await expect(card.getByRole('button', { name: 'Mock Trending One' })).toHaveAttribute(
		'aria-pressed',
		'true'
	);
	await card.getByRole('button', { name: 'Add 2 to Completed' }).click();

	await expect
		.poll(() =>
			calls
				.filter((c) => c.query.includes('mutation SaveEntry'))
				.map((c) => c.variables)
				.sort((a, b) => Number(a.mediaId) - Number(b.mediaId))
		)
		.toEqual([
			{ mediaId: 200002, status: 'COMPLETED' },
			{ mediaId: 200003, status: 'COMPLETED' }
		]);
	// the list isn't empty any more: regular Home, nothing in progress yet
	await expect(card).toHaveCount(0);
	await expect(page.getByText('Nothing in progress.', { exact: false })).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Trending now' })).toBeVisible();
});

test('the quick-pick can be skipped, and stays skipped', async ({ page }) => {
	await mockLoggedInEmpty(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const card = page.getByTestId('quick-pick');
	await expect(card.getByRole('link', { name: 'import from AniList' })).toHaveAttribute(
		'href',
		'https://anilist.co/settings/import'
	);
	await card.getByRole('button', { name: 'skip' }).click();
	await expect(card).toHaveCount(0);
	await expect(page.getByRole('heading', { name: 'Trending now' })).toBeVisible();

	await page.reload();
	await expect(page.getByRole('heading', { name: 'Trending now' })).toBeVisible();
	await expect(page.getByTestId('quick-pick')).toHaveCount(0);
});

test('anime/manga toggle swaps heading copy when logged in', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(page.getByRole('heading', { name: 'Continue watching' })).toBeVisible();

	await page.getByTestId('toggle-manga').click();
	await expect(page.getByRole('heading', { name: 'Continue reading' })).toBeVisible();

	await page.getByTestId('toggle-anime').click();
	await expect(page.getByRole('heading', { name: 'Continue watching' })).toBeVisible();
});

test('a failed home fetch shows a retryable error with the real detail message', async ({
	page
}) => {
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string };
		if (body.query.includes('query GetViewer')) {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify({
					data: {
						Viewer: {
							id: 1,
							name: 'haruka_k',
							avatar: {},
							bannerImage: null,
							unreadNotificationCount: 0
						}
					}
				})
			});
			return;
		}
		await route.fulfill({
			status: 400,
			contentType: 'application/json',
			body: JSON.stringify({ errors: [{ message: 'Mock validation error from AniList' }] })
		});
	});
	await page.addInitScript(() => localStorage.setItem('anilist_token', 'test-token'));

	await page.goto('/');

	// each section fails on its own, with AniList's own message
	const list = page.getByTestId('continue-error');
	await expect(list.getByText("Couldn't load your feed")).toBeVisible();
	await expect(list.getByText('Mock validation error from AniList')).toBeVisible();
	const feed = page.getByTestId('feed-error');
	await expect(feed.getByText("Couldn't load these rows")).toBeVisible();
	await expect(feed.getByText('Mock validation error from AniList')).toBeVisible();
});

test("Continue's +1 increments progress when logged in", async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const row = continueRow(page, 'Mock Continue Anime');
	await expect(row).toContainText('19 new · EP 5 / 24');
	// the other end of the title line: when the next one airs, or the time left
	await expect(row.getByTestId('continue-aside')).toBeVisible();
	await row.getByRole('button', { name: 'Add one episode to Mock Continue Anime' }).click();
	await expect(row).toContainText('EP 6 / 24');
});

test('signed in but offline shows a retrying error, not the logged-out page', async ({ page }) => {
	await page.addInitScript(() => {
		localStorage.setItem('anilist_token', 'test-token');
		Object.defineProperty(navigator, 'onLine', { get: () => false });
	});
	await page.route('https://graphql.anilist.co/**', (route) => route.abort());
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(page.getByText("Couldn't load your feed")).toBeVisible();
	await expect(page.getByTestId('retry-countdown')).toBeVisible();
	await expect(page.getByText('Every episode. Every chapter. One list.')).toHaveCount(0);
	// the token is kept, so a retry can recover
	expect(await page.evaluate(() => localStorage.getItem('anilist_token'))).toBe('test-token');
});

test('a failed list keeps the rows: errors are scoped to their section', async ({ page }) => {
	await mockRateLimitedHome(page, 99, 60, 'HomeList');
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const error = page.getByTestId('continue-error');
	await expect(error.getByRole('heading', { name: 'Continue watching' })).toBeVisible();
	await expect(error.getByText('AniList is busy right now')).toBeVisible();
	// the rows came back fine and stay usable
	await expect(page.getByRole('heading', { name: 'Trending now' })).toBeVisible();
	await expect(page.getByRole('group', { name: 'Mock Trending One' }).last()).toBeVisible();
});

test('failed rows keep Continue', async ({ page }) => {
	await mockRateLimitedHome(page, 99, 60, 'HomeFeed');
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(continueRow(page, 'Mock Continue Anime')).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Continue watching' })).toBeVisible();
	await expect(page.getByTestId('feed-error').getByText('AniList is busy right now')).toBeVisible();
});

test('rows link to See all, and the hero links to the title', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await expect(page.getByRole('link', { name: 'See all: Trending now' })).toHaveAttribute(
		'href',
		'/browse?sort=trending'
	);
	// no For You picks: the hero shows the season's most popular, so its row doesn't repeat it
	await expect(page.getByTestId('hero-reason')).toHaveText(
		/Popular in (Winter|Spring|Summer|Fall) \d{4}/
	);
	await expect(page.getByRole('link', { name: 'See all: Popular this season' })).toHaveCount(0);
	// next season's chart
	await expect(page.getByRole('link', { name: 'See all: Upcoming' })).toHaveAttribute(
		'href',
		/^\/seasonal\?season=(winter|spring|summer|fall)&year=\d{4}$/
	);
	await expect(page.getByRole('link', { name: 'More about Mock Popular One' })).toHaveAttribute(
		'href',
		'/title/200004'
	);
	// no banner on the mock title: the blurred cover stands in
	await expect(page.getByTestId('hero-banner-fallback')).toBeAttached();
});

test('Plan on an upcoming title adds it as Planning', async ({ page }) => {
	const calls = await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	await page.getByRole('button', { name: 'Plan Mock Upcoming One' }).click();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 200005, status: 'PLANNING' });
	await expect(page.getByRole('button', { name: 'Plan Mock Upcoming One' })).toHaveCount(0);
	await expect(page.getByText('Planning').first()).toBeVisible();
});

// five scored titles (10-point decimal, the mock account's format): enough for For You
const RATED = [
	{ id: 600001, title: 'Frieren', status: 'COMPLETED' as const, progress: 28, score: 9.5 },
	{ id: 600002, title: 'Apothecary', status: 'COMPLETED' as const, progress: 24, score: 9 },
	{ id: 600003, title: 'Dandadan', status: 'COMPLETED' as const, progress: 12, score: 8 },
	{ id: 600004, title: 'Okay One', status: 'COMPLETED' as const, progress: 12, score: 6 },
	{ id: 600005, title: 'Okay Two', status: 'COMPLETED' as const, progress: 12, score: 5 }
];

test('the hero recommends For You picks, with Plan and Not this', async ({ page }) => {
	await page.clock.install();
	const calls = await mockLoggedIn(page);
	await mockListCollection(page, RATED);
	await mockForYou(page, {
		600001: [
			{ id: 610001, title: 'Pick One', rating: 120 },
			{ id: 610002, title: 'Pick Two', rating: 60 },
			{ id: 610003, title: 'Pick Three', rating: 40 }
		]
	});
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const hero = page.getByRole('region', { name: 'Picked for you' });
	await expect(hero.getByRole('heading', { name: 'Pick One' })).toBeVisible();
	await expect(hero.getByTestId('hero-reason')).toHaveText('Because you rated Frieren 9.5/10');
	const dots = hero.getByRole('group', { name: 'Choose slide' }).first();
	await expect(dots.getByRole('button')).toHaveCount(3);

	// pick a slide; arrow keys move between them from the dots
	await dots.getByRole('button', { name: /Pick Three/ }).click();
	await expect(hero.getByRole('heading', { name: 'Pick Three' })).toBeVisible();
	await page.keyboard.press('ArrowLeft');
	await expect(hero.getByRole('heading', { name: 'Pick Two' })).toBeVisible();

	// it never moves on by itself
	await page.mouse.move(5, 890);
	await page.locator('body').click({ position: { x: 5, y: 890 } });
	await page.clock.runFor(10_000);
	await expect(hero.getByRole('heading', { name: 'Pick Two' })).toBeVisible();

	// Plan adds the slide showing (once the old one has faded out)
	await expect(hero.getByTestId('hero-plan')).toHaveCount(1);
	await hero.getByTestId('hero-plan').click();
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 610002, status: 'PLANNING' });
	await expect(hero.getByTestId('hero-plan')).toHaveCount(0);

	// Not this hides it, with Undo
	await hero.getByRole('button', { name: 'Not this: hide Pick Two' }).click();
	await expect(hero.getByRole('heading', { name: 'Pick Two' })).toHaveCount(0);
	await expect(page.getByTestId('toast')).toContainText('Hid Pick Two from your picks');
});

test('the hero synopsis stops at three lines', async ({ page }) => {
	await mockLoggedIn(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const synopsis = page.getByTestId('hero-synopsis');
	await expect(synopsis).toBeVisible();
	const lines = await synopsis.evaluate((el) => {
		el.textContent = 'A very long synopsis that keeps going. '.repeat(40);
		const style = getComputedStyle(el);
		return Math.round(el.getBoundingClientRect().height / parseFloat(style.lineHeight));
	});
	expect(lines).toBe(3);
});

// AniList's 429 has no CORS headers, so the browser sees only a failed request
test('a request AniList refuses while online counts down like a rate limit', async ({ page }) => {
	await page.route('https://graphql.anilist.co/**', (route) => route.abort('failed'));
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/title/30013');

	await expect(page.getByText('AniList is busy right now')).toBeVisible();
	await expect(page.getByTestId('retry-countdown')).toHaveText(/^[01]:\d\d$/);
	await expect(page.getByText('Failed to fetch')).toHaveCount(0);
});

test('Up next says Start, and how long each one is', async ({ page }) => {
	await mockLoggedIn(page, 'haruka_k', { upNext: 2 });
	await page.setViewportSize({ width: 1440, height: 900 });
	await page.goto('/');

	const row = continueRow(page, 'Mock Up Next 1');
	await expect(row.getByTestId('continue-aside')).toHaveText('12 eps');
	await expect(row.getByRole('button', { name: 'Start Mock Up Next 1' })).toHaveText('Start');
});
