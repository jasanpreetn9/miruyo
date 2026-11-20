import { describe, expect, it } from 'vitest';
import { makeCharacter, makeDetail, makePersonMedia, makeStaff } from '#lib/anilist/fixtures.ts';
import {
	characterMeta,
	routeMeta,
	SITEMAP_PATHS,
	staffMeta,
	studioMeta,
	summarize,
	titleMeta
} from './seo.ts';

describe('routeMeta', () => {
	it('uses the route’s headline and description', () => {
		const meta = routeMeta('/seasonal');
		expect(meta.title).toBe('Seasonal anime chart · miruyo');
		expect(meta.description).toMatch(/^Every anime airing this season/);
		expect(meta.noindex).toBe(false);
		expect(meta.image.url).toBe('https://miruyo.jnagra.com/og.png');
	});

	it('keeps personal pages and unknown routes out of the index', () => {
		expect(routeMeta('/list').noindex).toBe(true);
		expect(routeMeta(null).noindex).toBe(true);
		expect(routeMeta('/nope').noindex).toBe(true);
	});

	it('lets a page’s own tags win', () => {
		const meta = routeMeta('/title/[id]', {
			title: 'Frieren',
			description: 'An elf mage.',
			image: { url: 'https://example.com/banner.jpg', alt: 'Frieren' },
			canonical: '/title/1'
		});
		expect(meta.title).toBe('Frieren · miruyo');
		expect(meta.description).toBe('An elf mage.');
		expect(meta.image.url).toBe('https://example.com/banner.jpg');
		expect(meta.canonical).toBe('/title/1');
	});

	it('lists only public pages in the sitemap', () => {
		expect(SITEMAP_PATHS).toContain('/seasonal');
		expect(SITEMAP_PATHS).not.toContain('/list');
		expect(SITEMAP_PATHS).not.toContain('/title/[id]');
	});
});

describe('summarize', () => {
	it('leaves short text alone, flattening whitespace', () => {
		expect(summarize('One\n\ntwo  three')).toBe('One two three');
	});

	it('cuts long text at a word', () => {
		const text = 'word '.repeat(50);
		const out = summarize(text, 40);
		expect(out.length).toBeLessThanOrEqual(40);
		expect(out).toMatch(/word…$/);
	});
});

describe('titleMeta', () => {
	it('names the title in English, with its synopsis and banner', () => {
		const meta = titleMeta(
			makeDetail({
				id: 154587,
				description: 'An elf <i>mage</i>.<br>Her journey.',
				bannerImage: 'https://example.com/banner.jpg',
				coverImage: {
					extraLarge: 'https://example.com/cover.jpg',
					large: null,
					medium: null,
					color: null
				}
			})
		);
		expect(meta.title).toBe('English Title');
		expect(meta.description).toBe('An elf mage. Her journey.');
		expect(meta.image).toEqual({ url: 'https://example.com/banner.jpg', alt: 'English Title' });
		expect(meta.noindex).toBe(false);
		expect(meta.jsonLd).toMatchObject({
			'@type': 'TVSeries',
			name: 'English Title',
			alternateName: ['Romaji Title'],
			image: 'https://example.com/cover.jpg',
			datePublished: '2026-10-02',
			numberOfEpisodes: 24,
			url: 'https://miruyo.jnagra.com/title/154587',
			sameAs: 'https://anilist.co/anime/154587'
		});
	});

	it('falls back to the romaji name and a stock description', () => {
		const meta = titleMeta(
			makeDetail({
				type: 'MANGA',
				title: { romaji: 'Romaji', english: null, native: null, userPreferred: null },
				description: null
			})
		);
		expect(meta.title).toBe('Romaji');
		expect(meta.description).toMatch(/AniList manga list/);
		expect(meta.image).toBeUndefined();
		expect(meta.jsonLd?.['@type']).toBe('Book');
		expect(meta.jsonLd).not.toHaveProperty('description');
	});

	it('heads an airing show’s search result with its next episode', () => {
		const meta = titleMeta(
			makeDetail({
				description: 'An elf mage.',
				nextAiringEpisode: { episode: 12, airingAt: 0, timeUntilAiring: 0 }
			})
		);
		expect(meta.headline).toBe('English Title Episode 12 Release Date & Countdown');
		expect(meta.description).toBe(
			'Countdown to episode 12 in your time zone, with the airing schedule, studio and cast. An elf mage.'
		);
	});

	it('heads other titles with their release date, or their year and kind', () => {
		expect(titleMeta(makeDetail({ status: 'NOT_YET_RELEASED' })).headline).toBe(
			'English Title: Release Date & Details'
		);
		expect(titleMeta(makeDetail({ status: 'FINISHED' })).headline).toBe(
			'English Title (2026 TV Anime)'
		);
		expect(
			titleMeta(
				makeDetail({
					type: 'MANGA',
					format: 'NOVEL',
					status: 'FINISHED',
					startDate: { year: 2015, month: 1, day: 1 }
				})
			).headline
		).toBe('English Title (2015 Light Novel)');
	});

	it('calls a movie a Movie, and keeps 18+ titles out of the index', () => {
		const meta = titleMeta(makeDetail({ format: 'MOVIE', isAdult: true }));
		expect(meta.jsonLd?.['@type']).toBe('Movie');
		expect(meta.noindex).toBe(true);
	});
});

describe('people', () => {
	it('gives a staff page its own card and Person data', () => {
		const meta = staffMeta(
			makeStaff({
				description:
					'__Height:__ 157 cm\n\n[Twitter](https://twitter.com/x) | [Profile](https://x.jp)\n\nA Japanese voice actress.'
			})
		);
		expect(meta.title).toBe('Atsumi Tanezaki');
		expect(meta.description).toBe('A Japanese voice actress.');
		expect(meta.image?.url).toBe('https://s4.anilist.co/staff.jpg');
		expect(meta.jsonLd).toMatchObject({
			'@type': 'Person',
			name: 'Atsumi Tanezaki',
			jobTitle: 'Voice Actor',
			sameAs: 'https://anilist.co/staff/112215'
		});
		expect(routeMeta('/staff/[id]', meta).noindex).toBe(false);
	});

	it('keeps a character’s spoilers out of search results and share cards', () => {
		const meta = characterMeta(
			makeCharacter({ description: 'A thousand-year-old mage. ~!She outlives them all.!~' })
		);
		expect(meta.description).toBe('A thousand-year-old mage.');
		expect(meta.title).toBe('Frieren');
	});
});

describe('studioMeta', () => {
	it('names the studio, what it is and its best-known titles, as an Organization', () => {
		const meta = studioMeta({
			id: 11,
			name: 'MADHOUSE',
			isAnimationStudio: true,
			siteUrl: null,
			favourites: 1,
			isFavourite: false,
			media: {
				pageInfo: { total: 4, hasNextPage: false },
				edges: ['Death Note', 'Hunter x Hunter', 'One-Punch Man', 'Overlord'].map((t, i) => ({
					isMainStudio: true,
					node: makePersonMedia({
						id: i + 1,
						title: { romaji: t, english: t, native: null, userPreferred: t }
					})
				}))
			}
		});
		expect(meta.title).toBe('MADHOUSE');
		expect(meta.description).toBe(
			'MADHOUSE, animation studio: Death Note, Hunter x Hunter, One-Punch Man and more. Its titles on miruyo.'
		);
		expect(meta.jsonLd).toMatchObject({
			'@type': 'Organization',
			url: 'https://miruyo.jnagra.com/studio/11',
			sameAs: 'https://anilist.co/studio/11'
		});
	});

	it('is indexed, like the staff and character pages', () => {
		expect(routeMeta('/studio/[id]').noindex).toBe(false);
	});
});
