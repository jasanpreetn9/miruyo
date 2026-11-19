import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockDetail, mockLoggedIn, type AniListCall } from './mock-auth.ts';

const NOW = Math.floor(Date.now() / 1000);

const NOTIFICATIONS = [
	{
		__typename: 'AiringNotification',
		id: 1,
		createdAt: NOW - 2 * 3600,
		episode: 5,
		contexts: ['Episode ', ' of ', ' aired.'],
		media: {
			id: 154587,
			type: 'ANIME',
			title: { userPreferred: 'Frieren' },
			coverImage: { medium: '' }
		}
	},
	{
		__typename: 'FollowingNotification',
		id: 2,
		createdAt: NOW - 3 * 86400,
		context: ' started following you.',
		user: { id: 7, name: 'rin', avatar: { medium: '' } }
	},
	// a type miruyo doesn't show
	{ __typename: 'MediaSubmissionUpdateNotification' }
];

/** Signed in with `unread` unread notifications; AniList's list as above. */
async function mockNotifications(page: Page, unread: number, notifications = NOTIFICATIONS) {
	const calls = await mockLoggedIn(page, undefined, { unreadNotifications: unread });
	// registered after mockLoggedIn, so it wins; everything else falls through
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (!query.includes('query Notifications')) return route.fallback();
		calls.push({ query, variables: {} });
		await route.fulfill({ json: { data: { Page: { notifications } } } });
	});
	return calls;
}

const notificationQueries = (calls: AniListCall[]) =>
	calls.filter((c) => c.query.includes('query Notifications'));

test('the bell shows unread, lists notifications and marks them read', async ({ page }) => {
	const calls = await mockNotifications(page, 1);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');

	const bell = page.getByRole('banner').getByRole('button', { name: 'Notifications, 1 unread' });
	await expect(bell).toBeVisible();
	await expect(page.getByTestId('unread-dot').first()).toBeVisible();
	expect(notificationQueries(calls)).toHaveLength(0);

	await bell.click();
	const panel = page.getByRole('dialog', { name: 'Notifications' });
	await expect(panel).toBeVisible();

	const airing = panel.getByRole('link', { name: /Episode 5 of Frieren aired\.\s*2h ago\s*New/ });
	await expect(airing).toHaveAttribute('href', '/title/154587');
	const follow = panel.getByRole('link', { name: /rin started following you\.\s*3d ago$/ });
	await expect(follow).toHaveAttribute('href', '/user/rin');
	await expect(panel.getByRole('listitem')).toHaveCount(2);

	// opening the list read them, as on AniList
	const readBell = page
		.getByRole('banner')
		.getByRole('button', { name: 'Notifications', exact: true });
	await expect(readBell).toBeVisible();
	await expect(page.getByTestId('unread-dot')).toHaveCount(0);

	await page.keyboard.press('Escape');
	await expect(panel).toBeHidden();

	// a title notification opens the title in miruyo
	await mockDetail(page);
	await readBell.click();
	await page.getByRole('link', { name: /Episode 5 of Frieren/ }).click();
	await expect(page).toHaveURL(/\/title\/154587$/);
});

test('an empty list says so', async ({ page }) => {
	await mockNotifications(page, 0, []);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');
	await page
		.getByRole('banner')
		.getByRole('button', { name: 'Notifications', exact: true })
		.click();
	await expect(page.getByText('No notifications yet.')).toBeVisible();
});

test('signed out, there is no bell', async ({ page }) => {
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/login');
	await expect(page.getByRole('button', { name: /^Notifications/ })).toHaveCount(0);
});

test('mobile: the bell is in the header and the list spans the screen', async ({ page }) => {
	await mockNotifications(page, 2);
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/');
	await page.getByRole('button', { name: 'Notifications, 2 unread' }).click();
	const panel = page.getByRole('dialog', { name: 'Notifications' });
	await expect(panel.getByRole('listitem')).toHaveCount(2);
	const box = await panel.boundingBox();
	expect(box!.width).toBeGreaterThan(350);
	// clicking outside closes it
	await page.mouse.click(195, 700);
	await expect(panel).toBeHidden();
});
