import { describe, expect, it } from 'vitest';
import { makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import type { Profile, ProfileResponse } from '#lib/anilist/types.ts';
import { buildProfile } from './profile.ts';

const viewerData = (
	overrides: Partial<ProfileResponse['Viewer']> = {}
): ProfileResponse['Viewer'] => ({
	id: 1,
	createdAt: Date.UTC(2019, 2, 14) / 1000,
	siteUrl: 'https://anilist.co/user/haruka_k',
	favourites: {
		anime: { nodes: [{ id: 1 }, { id: 2 }] },
		manga: { nodes: [{ id: 3 }] },
		characters: {
			nodes: [
				{
					id: 40,
					name: { userPreferred: 'Frieren' },
					image: { large: 'frieren.png', medium: null },
					siteUrl: null
				}
			]
		},
		staff: { nodes: [] },
		studios: { nodes: [{ id: 7, name: 'Madhouse', siteUrl: 'https://anilist.co/studio/7' }] }
	},
	...overrides
});

const viewer = (overrides: Partial<ProfileResponse['Viewer']> = {}): Profile => ({
	account: viewerData(overrides),
	anime: [makeMedia({ id: 1 }), makeMedia({ id: 2, isAdult: true })],
	manga: [makeManga({ id: 3 })],
	titlesError: null
});

describe('buildProfile', () => {
	it('says when the account was made', () => {
		expect(buildProfile(viewer(), { timeZone: 'UTC', showAdult: false }).memberSince).toBe(
			'Member since March 2019'
		);
		expect(
			buildProfile(viewer({ createdAt: null }), { timeZone: 'UTC', showAdult: false }).memberSince
		).toBeNull();
	});

	it('lists favourites, hiding 18+ titles unless the account shows them', () => {
		const hidden = buildProfile(viewer(), { showAdult: false });
		expect(hidden.anime.map((t) => t.id)).toEqual([1]);
		expect(hidden.manga.map((t) => t.id)).toEqual([3]);
		expect(buildProfile(viewer(), { showAdult: true }).anime.map((t) => t.id)).toEqual([1, 2]);
	});

	it('lists a favourite once, even when AniList lists it twice', () => {
		const twice: Profile = {
			...viewer(),
			anime: [makeMedia({ id: 1 }), makeMedia({ id: 79 }), makeMedia({ id: 79 })]
		};
		expect(buildProfile(twice, { showAdult: false }).anime.map((t) => t.id)).toEqual([1, 79]);
	});

	it('links people and studios to their miruyo pages', () => {
		const view = buildProfile(viewer(), { showAdult: false });
		expect(view.characters).toEqual([
			{ id: 40, name: 'Frieren', image: 'frieren.png', href: '/character/40' }
		]);
		expect(view.studios).toEqual([{ id: 7, name: 'Madhouse', href: '/studio/7' }]);
		expect(view.anilistHref).toBe('https://anilist.co/user/haruka_k');
	});

	it('copes with no favourites at all', () => {
		const view = buildProfile(
			{ ...viewer({ favourites: null }), anime: [], manga: [] },
			{ showAdult: false }
		);
		expect(view).toMatchObject({ anime: [], manga: [], characters: [], staff: [], studios: [] });
	});

	it('keeps the rest when the titles failed', () => {
		const view = buildProfile(
			{ ...viewer(), anime: null, manga: null, titlesError: 'Internal Server Error' },
			{ showAdult: false }
		);
		expect(view).toMatchObject({ anime: [], manga: [], titlesError: 'Internal Server Error' });
		expect(view.characters).toHaveLength(1);
	});
});
