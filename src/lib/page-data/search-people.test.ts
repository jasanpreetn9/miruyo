import { describe, expect, it } from 'vitest';
import type { SearchPeopleResponse } from '#lib/anilist/types.ts';
import { buildPeopleResults, hasPeople } from './search-people.ts';

const DATA: SearchPeopleResponse = {
	characters: {
		characters: [
			{
				id: 1,
				name: { userPreferred: 'Frieren' },
				image: { large: 'https://s4.anilist.co/c.png', medium: null },
				media: {
					nodes: [
						{
							title: {
								userPreferred: 'Sousou no Frieren',
								english: "Frieren: Beyond Journey's End",
								romaji: 'Sousou no Frieren'
							}
						}
					]
				}
			}
		]
	},
	staff: {
		staff: [
			{
				id: 2,
				name: { userPreferred: 'Atsumi Tanezaki' },
				image: null,
				primaryOccupations: ['Voice Actor', 'Singer']
			}
		]
	},
	users: {
		users: [
			{ id: 3, name: 'Josh', avatar: { large: null, medium: 'https://s4.anilist.co/a.png' } },
			{ id: 4, name: 'a/b c', avatar: null }
		]
	},
	studios: {
		studios: [
			{
				id: 11,
				name: 'MADHOUSE',
				siteUrl: 'https://anilist.co/studio/11',
				isAnimationStudio: true
			},
			{ id: 12, name: 'Aniplex', siteUrl: 'javascript:alert(1)', isAnimationStudio: false },
			{ id: 13, name: 'Odd Studio', siteUrl: 'https://evil.example/13', isAnimationStudio: true }
		]
	}
};

describe('buildPeopleResults', () => {
	it('links people to their miruyo pages, with what they are known for', () => {
		const r = buildPeopleResults(DATA, { isAnime: true, titles: 'english' });
		expect(r.characters[0]).toEqual({
			id: 1,
			name: 'Frieren',
			image: 'https://s4.anilist.co/c.png',
			sub: "Frieren: Beyond Journey's End",
			href: '/character/1'
		});
		expect(r.staff[0]).toMatchObject({ sub: 'Voice Actor', href: '/staff/2' });
		// signed in, the account's own title language
		expect(
			buildPeopleResults(DATA, { isAnime: true, titles: 'userPreferred' }).characters[0].sub
		).toBe('Sousou no Frieren');
	});

	it('links users to their pages in either mode, the name encoded', () => {
		for (const isAnime of [true, false]) {
			expect(buildPeopleResults(DATA, { isAnime, titles: 'english' }).users).toEqual([
				{
					id: 3,
					name: 'Josh',
					image: 'https://s4.anilist.co/a.png',
					sub: null,
					href: '/user/Josh'
				},
				{ id: 4, name: 'a/b c', image: null, sub: null, href: '/user/a%2Fb%20c' }
			]);
		}
	});

	it('keeps animation studios, linking to their miruyo pages', () => {
		const { studios } = buildPeopleResults(DATA, { isAnime: true, titles: 'english' });
		expect(studios).toEqual([
			{ id: 11, name: 'MADHOUSE', href: '/studio/11' },
			{ id: 13, name: 'Odd Studio', href: '/studio/13' }
		]);
	});

	it('leaves studios out of manga searches', () => {
		expect(buildPeopleResults(DATA, { isAnime: false, titles: 'english' }).studios).toEqual([]);
	});

	it('knows when nothing matched', () => {
		const none = buildPeopleResults(
			{
				characters: { characters: [] },
				staff: { staff: [] },
				users: { users: [] },
				studios: { studios: [] }
			},
			{ isAnime: true, titles: 'english' }
		);
		expect(hasPeople(none)).toBe(false);
		expect(hasPeople(buildPeopleResults(DATA, { isAnime: false, titles: 'english' }))).toBe(true);
	});
});
