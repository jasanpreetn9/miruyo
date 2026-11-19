import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockDetail, mockLoggedIn } from './mock-auth.ts';

const desktop = (page: Page) => page.setViewportSize({ width: 1440, height: 900 });

test('the title page shows the title, its stats, countdown and sections', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await expect(
		page.getByRole('heading', { level: 1, name: "Frieren: Beyond Journey's End" })
	).toBeVisible();
	await expect(page.getByText('Highest rated all time')).toBeVisible();
	await expect(page.getByText('912k')).toBeVisible();
	await expect(page.getByText('Episode 9 airs in')).toBeVisible();
	await expect(page.getByRole('link', { name: /Watch the trailer/ })).toHaveAttribute(
		'href',
		'https://www.youtube.com/watch?v=abc123'
	);

	const info = page.getByRole('complementary');
	await expect(info.getByText('Studio', { exact: true })).toBeVisible();
	await expect(info.getByText('Mock Studio')).toBeVisible();

	await expect(page.getByText('Mock Hero').first()).toBeVisible();
	await expect(page.getByRole('link', { name: /Mock Sequel/ })).toHaveAttribute(
		'href',
		'/title/300200'
	);
	await expect(page.getByRole('group', { name: 'Mock Recommendation' })).toBeVisible();
});

test('where to watch, tags with spoilers hidden, links and other names', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await expect(
		page.getByTestId('detail-watch').getByRole('link', { name: /Crunchyroll/ })
	).toHaveAttribute('href', 'https://www.crunchyroll.com/series/mock');

	const tags = page.getByTestId('detail-tags');
	await expect(tags.getByRole('link', { name: /Travel/ })).toHaveAttribute(
		'href',
		'/browse?tag=Travel'
	);
	await expect(tags.getByText('Time Skip')).toHaveCount(0);
	// the eight best-fitting tags, then the rest on request
	await expect(tags.getByRole('link')).toHaveCount(8);
	await expect(tags.getByText('Philosophy')).toHaveCount(0);
	const more = tags.getByRole('button', { name: '2 more' });
	await expect(more).toHaveAttribute('aria-expanded', 'false');
	await more.click();
	await expect(tags.getByRole('link')).toHaveCount(10);
	await expect(tags.getByRole('link', { name: /Philosophy/ })).toBeVisible();
	await tags.getByRole('button', { name: 'Show fewer' }).click();
	await expect(tags.getByRole('link')).toHaveCount(8);

	// showing spoilers shows every tag, so one ranked low isn't left folded away
	await tags.getByRole('button', { name: 'Show 1 spoiler' }).click();
	await expect(tags.getByRole('link', { name: /Time Skip.*spoiler/ })).toBeVisible();
	await expect(tags.getByRole('link')).toHaveCount(11);

	await expect(page.getByRole('link', { name: /Official Site/ })).toBeVisible();
	await expect(page.getByText('Frieren at the Funeral')).toBeVisible();
});

test('tabs switch sections, also from the keyboard', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('tab', { name: 'Relations' }).click();
	await expect(page.getByRole('tabpanel').getByText('Sequel', { exact: true })).toBeVisible();
	await page.keyboard.press('ArrowRight');
	await expect(page.getByRole('tab', { name: 'Characters & Staff' })).toHaveAttribute(
		'aria-selected',
		'true'
	);
	await expect(page.getByRole('tabpanel').getByText('Mock Voice')).toBeVisible();
});

test('the Stats tab: rankings linking to Browse, lists and scores', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('tab', { name: 'Stats' }).click();
	const panel = page.getByRole('tabpanel');
	// all time first
	const rankings = panel.getByRole('region', { name: 'Rankings' }).getByRole('link');
	await expect(rankings).toHaveText([/#12\s*Highest rated\s*All time · TV/, /#3.*Fall 2023 · TV/]);
	await expect(rankings.first()).toHaveAttribute('href', '/browse?sort=score&format=TV');

	const lists = page.getByTestId('title-status-stats');
	await expect(lists).toContainText('10k people');
	await expect(lists.getByRole('listitem')).toHaveText([
		/Watching\s*2k\s*20%/,
		/Completed\s*5k\s*50%/,
		/Planning\s*3k\s*25%/,
		/Dropped\s*500\s*5%/
	]);

	const scores = page.getByTestId('title-score-stats');
	await expect(scores).toContainText('Average 8.8');
	await expect(scores.getByRole('listitem')).toHaveCount(10);
	await expect(scores.getByRole('listitem', { name: '6,000 scored it 10' })).toBeVisible();
});

test('signed out, adding to the list leads to log in', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await page.getByTestId('detail-status').first().click();
	await expect(page).toHaveURL('/login');
});

test('signed in, the status column shows the entry, +1 saves and favourites toggle', async ({
	page
}) => {
	const calls = await mockLoggedIn(page);
	const detailCalls = await mockDetail(page, {
		entry: { status: 'CURRENT', progress: 5, score: 8 }
	});
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	const aside = page.getByRole('complementary');
	await expect(aside.getByTestId('detail-status')).toContainText('Watching');
	const progress = aside.getByTestId('detail-progress');
	await expect(progress).toContainText('5 / 28');
	await expect(progress).toContainText('8.0');

	await progress.getByRole('button', { name: 'Add one episode' }).click();
	await expect(progress).toContainText('6 / 28');
	await expect
		.poll(() => calls.find((c) => c.query.includes('mutation SaveEntry'))?.variables)
		.toEqual({ mediaId: 300100, progress: 6 });

	await aside.getByRole('button', { name: 'Add to favourites' }).click();
	await expect(aside.getByRole('button', { name: 'Remove from favourites' })).toBeVisible();
	await expect
		.poll(() => detailCalls.find((c) => c.query.includes('ToggleFavourite'))?.variables)
		.toEqual({ animeId: 300100 });
});

test('poster titles link to their page', async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/');

	await page.getByRole('link', { name: 'Mock Trending One' }).last().click();
	await expect(page).toHaveURL('/title/200002');
	await expect(page.getByRole('heading', { level: 1, name: 'Mock Title 200002' })).toBeVisible();
});

test('a related title opens on the same page, starting fresh', async ({ page }) => {
	await mockDetail(page);
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	await page.getByRole('tab', { name: 'Relations' }).click();
	await page
		.getByRole('tabpanel')
		.getByRole('link', { name: /Mock Sequel/ })
		.click();
	await expect(page).toHaveURL('/title/300200');
	await expect(page.getByRole('heading', { level: 1, name: 'Mock Title 300200' })).toBeVisible();
	await expect(page.getByRole('tab', { name: 'Overview' })).toHaveAttribute(
		'aria-selected',
		'true'
	);
});

test('a bad id shows not found', async ({ page }) => {
	await desktop(page);
	await gotoHydrated(page, '/title/not-a-number');
	await expect(page.getByRole('heading', { name: "This title doesn't exist" })).toBeVisible();
});

test('mobile: back and share over the banner, Edit opens the editor', async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page, { entry: { status: 'CURRENT', progress: 5 } });
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/title/300100');

	await expect(page.getByRole('button', { name: 'Back' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Share' })).toBeVisible();
	await page.getByTestId('detail-status').last().click();
	await expect(page.getByTestId('list-editor')).toBeVisible();
});

test('signed in, recommendations show their list status', async ({ page }) => {
	await mockLoggedIn(page);
	const calls = await mockDetail(page, { onList: { 300300: 'CURRENT' } });
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	const rec = page.getByRole('group', { name: 'Mock Recommendation' });
	await expect(
		rec.getByText('Watching · 3/24', { exact: true }).filter({ visible: true })
	).toBeVisible();
	expect(calls.find((c) => c.query.includes('query ListEntries'))?.variables).toMatchObject({
		ids: [300300]
	});
});

test("the progress card says what's new and offers to rate it", async ({ page }) => {
	await mockLoggedIn(page);
	await mockDetail(page, { entry: { status: 'CURRENT', progress: 5, score: 0 } });
	await desktop(page);
	await gotoHydrated(page, '/title/300100');

	const progress = page.getByRole('complementary').getByTestId('detail-progress');
	await expect(progress.getByTestId('detail-progress-word')).toHaveText(/\d+ (new|left)|Caught up/);
	await progress.getByRole('button', { name: 'Not scored, rate it' }).click();
	await expect(page.getByRole('dialog')).toBeVisible();
});

test("the top bar's Anime / Manga switch follows the title you open", async ({ page }) => {
	await mockDetail(page, { type: 'MANGA' });
	await desktop(page);
	await gotoHydrated(page, '/title/300100');
	await expect(page.getByTestId('toggle-manga')).toHaveAttribute('aria-pressed', 'true');

	// switching back by hand while you're there stays switched
	await page.getByTestId('toggle-anime').click();
	await expect(page.getByTestId('toggle-anime')).toHaveAttribute('aria-pressed', 'true');
	await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
	await expect(page.getByTestId('toggle-anime')).toHaveAttribute('aria-pressed', 'true');
});
