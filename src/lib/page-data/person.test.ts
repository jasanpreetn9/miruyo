import { describe, expect, it } from 'vitest';
import { makeCharacter, makePersonMedia, makeStaff } from '#lib/anilist/fixtures.ts';
import { createCharacterContent, createStaffContent, formatDate } from './person.ts';

const character = (id: number, full: string) => ({
	id,
	name: { full, userPreferred: null },
	image: { medium: null }
});
const voice = (id: number, full: string, language: string, roleNotes: string | null = null) => ({
	roleNotes,
	voiceActor: {
		id,
		name: { full, userPreferred: null },
		image: { medium: null },
		languageV2: language
	}
});

describe('formatDate', () => {
	it('reads whatever parts AniList has', () => {
		expect(formatDate({ year: 1990, month: 9, day: 27 })).toBe('Sep 27, 1990');
		expect(formatDate({ year: null, month: 12, day: 25 })).toBe('Dec 25');
		expect(formatDate({ year: 1990, month: null, day: null })).toBe('1990');
		expect(formatDate({ year: null, month: null, day: null })).toBe('');
	});
});

describe('createStaffContent', () => {
	it('builds the header: names, facts from the API and the description, and the bio', () => {
		const content = createStaffContent(
			makeStaff({
				name: {
					full: 'Atsumi Tanezaki',
					native: '種﨑敦美',
					userPreferred: 'Atsumi Tanezaki',
					alternative: ['種崎敦美', 'atsumi tanezaki', 'Hana Kiritani']
				},
				homeTown: 'Oita Prefecture, Japan',
				description: '__Height:__ 157 cm\n\nA Japanese voice actress.'
			})
		);
		expect(content).toMatchObject({
			name: 'Atsumi Tanezaki',
			native: '種﨑敦美',
			altNames: ['種崎敦美', 'Hana Kiritani'],
			favourites: '4k',
			anilistHref: 'https://anilist.co/staff/112215'
		});
		expect(content.facts).toEqual([
			{ label: 'Occupation', value: 'Voice Actor' },
			{ label: 'Birthday', value: 'Sep 27, 1990' },
			{ label: 'Age', value: '36' },
			{ label: 'Gender', value: 'Female' },
			{ label: 'Years active', value: '2008 – present' },
			{ label: 'Hometown', value: 'Oita Prefecture, Japan' },
			{ label: 'Language', value: 'Japanese' },
			{ label: 'Height', value: '157 cm' }
		]);
		expect(content.bio).toEqual([[{ text: 'A Japanese voice actress.' }]]);
	});

	it('says when someone died instead of their age', () => {
		const content = createStaffContent(
			makeStaff({ dateOfDeath: { year: 2020, month: 1, day: 2 }, yearsActive: [1980] })
		);
		expect(content.facts).toContainEqual({ label: 'Died', value: 'Jan 2, 2020' });
		expect(content.facts).toContainEqual({ label: 'Years active', value: '1980 – ?' });
		expect(content.facts.find((f) => f.label === 'Age')).toBeUndefined();
	});

	it('makes a card per character voiced, leaving out 18+ titles unless allowed', () => {
		const staff = makeStaff({
			characterMedia: {
				pageInfo: { total: 3, hasNextPage: true },
				edges: [
					{
						characterRole: 'MAIN',
						characters: [character(10, 'Frieren')],
						node: makePersonMedia({ id: 1 })
					},
					{
						characterRole: 'SUPPORTING',
						characters: [character(11, 'Twin A'), character(12, 'Twin B'), null],
						node: makePersonMedia({ id: 2, format: 'MOVIE', startDate: { year: 2026 } })
					},
					{
						characterRole: 'MAIN',
						characters: [character(13, 'Hidden')],
						node: makePersonMedia({ id: 3, isAdult: true })
					}
				]
			}
		});
		const content = createStaffContent(staff, { titles: 'english' });
		expect(
			content.voiceRoles.map((r) => [r.character.name, r.role, r.media.title, r.media.meta])
		).toEqual([
			['Frieren', 'Main', 'English Title', '2023 · TV'],
			['Twin A', 'Supporting', 'English Title', '2026 · Movie'],
			['Twin B', 'Supporting', 'English Title', '2026 · Movie']
		]);
		expect(content.voiceHasMore).toBe(true);
		expect(content.voiceFirst).toBe(true);
		expect(createStaffContent(staff, { adult: true }).voiceRoles).toHaveLength(4);
	});

	it('folds several roles on one title into one credit, and leads with credits for authors', () => {
		const content = createStaffContent(
			makeStaff({
				primaryOccupations: ['Mangaka'],
				staffMedia: {
					pageInfo: { total: 3, hasNextPage: false },
					edges: [
						{ staffRole: 'Original Creator', node: makePersonMedia({ id: 1 }) },
						{ staffRole: 'Story & Art', node: makePersonMedia({ id: 1 }) },
						{ staffRole: 'Original Creator', node: makePersonMedia({ id: 2, type: 'MANGA' }) }
					]
				}
			})
		);
		expect(content.credits.map((c) => [c.media.id, c.roles])).toEqual([
			[1, 'Original Creator · Story & Art'],
			[2, 'Original Creator']
		]);
		expect(content.voiceFirst).toBe(false);
	});
});

describe('createCharacterContent', () => {
	it('keeps spoiler names apart and lists appearances with every voice', () => {
		const content = createCharacterContent(
			makeCharacter({
				name: {
					full: 'Frieren',
					native: 'フリーレン',
					userPreferred: 'Frieren',
					alternative: ['The Slayer'],
					alternativeSpoiler: ['Great Mage']
				},
				media: {
					pageInfo: { total: 3, hasNextPage: false },
					edges: [
						{
							characterRole: 'MAIN',
							voiceActorRoles: [
								voice(1, 'Atsumi Tanezaki', 'Japanese'),
								voice(2, 'Mallorie Rodak', 'English'),
								voice(3, 'Marie Nonnenmacher', 'French'),
								voice(1, 'Atsumi Tanezaki', 'Japanese')
							],
							node: makePersonMedia({ id: 1 })
						},
						{
							characterRole: 'MAIN',
							voiceActorRoles: [
								voice(4, 'Ji-Hyun Lee', 'Korean'),
								voice(5, 'Mallorie Rodak (young)', 'English', '(young)')
							],
							node: makePersonMedia({ id: 2 })
						},
						{
							characterRole: 'MAIN',
							voiceActorRoles: [],
							node: makePersonMedia({ id: 3, type: 'MANGA', format: 'MANGA' })
						}
					]
				}
			})
		);
		expect(content.altNames).toEqual(['The Slayer']);
		expect(content.spoilerNames).toEqual(['Great Mage']);
		expect(content.facts).toEqual([
			{ label: 'Gender', value: 'Female' },
			{ label: 'Age', value: '1000+' }
		]);
		expect(
			content.appearances.map((a) => [a.media.id, a.role, a.voices.map((v) => v.name)])
		).toEqual([
			[1, 'Main', ['Atsumi Tanezaki', 'Mallorie Rodak', 'Marie Nonnenmacher']],
			[2, 'Main', ['Ji-Hyun Lee', 'Mallorie Rodak (young)']],
			[3, 'Main', []]
		]);
		expect(content.appearances[1].voices[1].note).toBe('(young)');
		// Japanese, then English, then the rest by how many titles
		expect(content.languages).toEqual(['Japanese', 'English', 'French', 'Korean']);
	});
});
