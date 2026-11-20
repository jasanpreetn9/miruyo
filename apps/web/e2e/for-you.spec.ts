import { test, expect, type Page } from '@playwright/test';
import { gotoHydrated } from './helpers/hydrated.ts';
import {
	mockForYou,
	mockListCollection,
	mockLoggedIn,
	type MockListEntry
} from './helpers/mock-auth.ts';

// five scored titles (10-point decimal, the mock account's format)
const RATED: MockListEntry[] = [
	{ id: 600001, title: 'Frieren', status: 'COMPLETED', progress: 28, score: 9.5 },
	{ id: 600002, title: 'Apothecary', status: 'COMPLETED', progress: 24, score: 9 },
	{ id: 600003, title: 'Dandadan', status: 'COMPLETED', progress: 12, score: 8 },
	{ id: 600004, title: 'Okay One', status: 'COMPLETED', progress: 12, score: 6 },
	{ id: 600005, title: 'Okay Two', status: 'COMPLETED', progress: 12, score: 5 }
];

async function open(
	page: Page,
	url: string,
	entries = RATED,
	width = 1440,
	relations: Parameters<typeof mockForYou>[2] = {}
) {
	await mockLoggedIn(page);
	await mockListCollection(page, entries);
	await mockForYou(
		page,
		{
			600001: [
				{ id: 610001, title: 'Pick From Frieren', rating: 120 },
				{ id: 610003, title: 'Shared Pick', rating: 40 }
			],
			600002: [
				{ id: 610002, title: 'Pick From Apothecary', rating: 60 },
				{ id: 610003, title: 'Shared Pick', rating: 40 }
			],
			// already on the list, so never a pick
			600003: [{ id: 600001, title: 'Frieren', rating: 999 }]
		},
		relations
	);
	await page.setViewportSize({ width, height: 900 });
	await gotoHydrated(page, url);
}

const picks = (page: Page) => page.getByTestId('for-you-picks').getByRole('listitem');

test('Home: the hero recommends picks; a full row groups the rest by title', async ({ page }) => {
	await mockLoggedIn(page);
	await mockListCollection(page, RATED);
	await mockForYou(page, {
		// twelve from Frieren: five for the hero, seven for its row
		600001: Array.from({ length: 12 }, (_, i) => ({
			id: 620001 + i,
			title: `Frieren Pick ${i + 1}`,
			rating: 200 - i
		})),
		// two from Apothecary: too few for a row of their own
		600002: [
			{ id: 630001, title: 'Apothecary Pick 1', rating: 50 },
			{ id: 630002, title: 'Apothecary Pick 2', rating: 40 }
		]
	});
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/');

	const hero = page.getByRole('region', { name: 'Picked for you' });
	await expect(hero.getByTestId('hero-reason')).toHaveText('Because you rated Frieren 9.5/10');
	await expect(hero.getByRole('group', { name: 'Choose slide' }).getByRole('button')).toHaveCount(
		5
	);
	// the row is named once and leaves out what the hero shows
	await expect(page.getByRole('heading', { name: 'Because you loved Frieren' })).toBeVisible();
	await expect(page.getByRole('group', { name: 'Frieren Pick 6' }).last()).toBeVisible();
	await expect(page.getByRole('group', { name: 'Frieren Pick 1', exact: true })).toHaveCount(0);
	await expect(page.getByRole('heading', { name: 'Because you loved Apothecary' })).toHaveCount(0);
	await expect(
		page.getByRole('link', { name: 'See all: Because you loved Frieren' })
	).toHaveAttribute('href', '/for-you');
});

test('For You: the seed rail filters, and Not this hides a pick (with Undo)', async ({ page }) => {
	await open(page, '/for-you');
	await expect(page.getByRole('heading', { level: 1, name: 'For You' })).toBeVisible();
	// shared by two seeds, so it ranks first
	await expect(picks(page).first()).toContainText('Shared Pick');
	await expect(picks(page)).toHaveCount(3);

	await page
		.getByRole('group', { name: 'Filter picks by the title behind them' })
		.getByRole('button', { name: /Apothecary/ })
		.click();
	await expect(picks(page)).toHaveCount(2);
	await expect(page.getByTestId('for-you-picks')).not.toContainText('Pick From Frieren');
	await page.getByRole('button', { name: 'All picks' }).click();
	await expect(picks(page)).toHaveCount(3);

	await page.getByRole('button', { name: 'Not this: hide Pick From Frieren' }).click();
	await expect(picks(page)).toHaveCount(2);
	await page.getByRole('button', { name: 'Undo' }).click();
	await expect(picks(page)).toHaveCount(3);

	// hidden picks stay hidden after a reload
	await page.getByRole('button', { name: 'Not this: hide Pick From Frieren' }).click();
	await page.reload();
	await expect(picks(page)).toHaveCount(2);
});

test('fewer than five ratings: the cold start asks for a few more', async ({ page }) => {
	await open(page, '/for-you', RATED.slice(0, 3));
	const cold = page.getByTestId('for-you-cold-start');
	await expect(cold).toContainText('Picks get good after 5 ratings');
	await expect(cold).toContainText("You've rated 3 of 5");
	await expect(cold.getByRole('link', { name: 'Rate a few titles instead' })).toBeVisible();
});

test('signed out, For You asks you to log in', async ({ page }) => {
	await page.setViewportSize({ width: 390, height: 844 });
	await gotoHydrated(page, '/for-you');
	await expect(
		page.getByTestId('for-you-cold-start').getByRole('link', { name: 'Log in with AniList' })
	).toBeVisible();
});

test('Tune picks leaves out a genre, keeps it across a reload, and resets', async ({ page }) => {
	await open(page, '/for-you');
	await expect(picks(page)).toHaveCount(3);
	const tune = page.getByTestId('for-you-tune');
	await tune.getByRole('button', { name: 'Tune picks' }).click();
	await expect(tune.getByRole('button', { name: 'Tune picks' })).toHaveAttribute(
		'aria-expanded',
		'true'
	);

	// every mocked pick is Action: leaving it out leaves none, and says how to undo that
	await tune
		.getByRole('group', { name: 'Genres to leave out' })
		.getByRole('button', { name: 'Action' })
		.click();
	await expect(picks(page)).toHaveCount(0);
	await expect(page.getByText('Tune leaves out every pick.')).toBeVisible();
	await expect(tune.getByText('0 of 3 picks shown')).toBeVisible();

	await page.reload();
	await expect(page.getByText('Tune leaves out every pick.')).toBeVisible();
	await page.getByTestId('for-you-tune').getByRole('button', { name: 'Reset' }).click();
	await expect(picks(page)).toHaveCount(3);
});

test('the other list adds its anime, saying why, and Tune can leave them out', async ({ page }) => {
	// the mock serves the same titles as manga: Apothecary's anime joins the picks
	await open(page, '/for-you', RATED, 1440, {
		relations: {
			600002: [
				{ relationType: 'ADAPTATION', id: 630001, title: 'Apothecary: The Anime', type: 'ANIME' },
				{ relationType: 'SEQUEL', id: 630002, title: 'Not An Adaptation', type: 'MANGA' }
			]
		}
	});
	const grid = page.getByTestId('for-you-picks');
	await expect(grid).toContainText('Apothecary: The Anime');
	await expect(grid).toContainText('The anime of Apothecary, which you rated 9/10');
	await expect(grid).not.toContainText('Not An Adaptation');

	await page.getByRole('button', { name: 'Tune picks' }).click();
	await page.getByRole('checkbox', { name: /Anime of manga you loved/ }).uncheck();
	await expect(grid).not.toContainText('Apothecary: The Anime');
	await expect(picks(page)).toHaveCount(3);
});
