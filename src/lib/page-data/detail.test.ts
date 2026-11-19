import { describe, expect, it } from 'vitest';
import { makeDetail, makeMedia } from '#lib/anilist/fixtures.ts';
import type { DetailMedia } from '#lib/anilist/types.ts';
import {
	createDetailContent,
	formatAiring,
	formatAiringLong,
	formatCompact,
	humanizeEnum
} from './detail.ts';

const person = (id: number, full: string) => ({ id, name: { full }, image: { medium: null } });

describe('helpers', () => {
	it('formats member counts compactly', () => {
		expect(formatCompact(912_345)).toBe('912k');
		expect(formatCompact(1_234_567)).toBe('1.2M');
		expect(formatCompact(2_000_000)).toBe('2M');
		expect(formatCompact(640)).toBe('640');
		expect(formatCompact(null)).toBe('—');
	});

	it('humanizes AniList enums', () => {
		expect(humanizeEnum('SIDE_STORY')).toBe('Side story');
		expect(humanizeEnum('LIGHT_NOVEL')).toBe('Light novel');
		expect(humanizeEnum(null)).toBe('');
	});

	it('formats airing times in a given timezone', () => {
		// 2026-10-09 14:00 UTC is a Friday
		const at = Date.UTC(2026, 9, 9, 14, 0) / 1000;
		expect(formatAiring(at, 'UTC')).toBe('Fri 14:00');
		expect(formatAiring(at, 'Asia/Tokyo')).toBe('Fri 23:00');
		expect(formatAiringLong(at, 'Asia/Tokyo')).toBe('Fri, Oct 9 · 23:00');
	});
});

describe('createDetailContent', () => {
	it('builds the anime headline, rank and info table', () => {
		const content = createDetailContent(
			makeDetail({
				popularity: 912_345,
				rankings: [
					{ rank: 52, type: 'POPULAR', allTime: true, context: 'most popular all time' },
					{ rank: 2, type: 'RATED', allTime: true, context: 'highest rated all time' }
				],
				nextAiringEpisode: {
					episode: 9,
					airingAt: Date.UTC(2026, 9, 9, 14, 0) / 1000,
					timeUntilAiring: 1
				}
			}),
			{ timeZone: 'Asia/Tokyo' }
		);
		expect(content.overline).toBe('TV · Fall 2026 · Studio One');
		expect(content.altTitles).toBe('English Title');
		expect(content.rank).toEqual({ value: '#2', label: 'Highest rated all time' });
		expect(content.members).toBe('912k');
		expect(content.info).toEqual([
			{ label: 'Format', value: 'TV · 24 min' },
			{ label: 'Episodes', value: '24' },
			{ label: 'Status', value: 'Releasing' },
			{ label: 'Season', value: 'Fall 2026' },
			{ label: 'Studio', value: 'Studio One', href: '/studio/1' },
			{ label: 'Source', value: 'Manga' },
			{ label: 'Next episode', value: 'EP 9 · Fri 23:00' }
		]);
		expect(content.nextAiring).toEqual({ episode: 9, at: Date.UTC(2026, 9, 9, 14, 0) / 1000 });
	});

	it('falls back to the popularity rank, or none', () => {
		const popular = makeDetail({
			rankings: [{ rank: 5, type: 'POPULAR', allTime: true, context: '' }]
		});
		expect(createDetailContent(popular).rank).toEqual({
			value: '#5',
			label: 'Most popular all time'
		});
		expect(createDetailContent(makeDetail()).rank).toBeNull();
	});

	it('builds manga info with authors and an ongoing chapter count', () => {
		const content = createDetailContent(
			makeDetail({
				type: 'MANGA',
				format: 'MANGA',
				episodes: null,
				chapters: null,
				volumes: 8,
				season: null,
				seasonYear: null,
				startDate: { year: 2023, month: 9, day: 1 },
				studios: { nodes: [] },
				staff: {
					edges: [
						{ role: 'Story & Art', node: person(1, 'Takeru Hokazono') },
						{ role: 'Assistant', node: person(2, 'Someone Else') }
					]
				}
			})
		);
		expect(content.overline).toBe('Manga · 2023 – present');
		expect(content.authors.map((a) => a.name)).toEqual(['Takeru Hokazono']);
		expect(content.info).toEqual([
			{ label: 'Format', value: 'Manga' },
			{ label: 'Chapters', value: 'Ongoing' },
			{ label: 'Volumes', value: '8' },
			{ label: 'Status', value: 'Releasing' },
			{ label: 'Story & Art', value: 'Takeru Hokazono' },
			{ label: 'Started', value: 'Sep 2023' }
		]);
	});

	it('orders relations by kind and labels them', () => {
		const node = (id: number, type: 'ANIME' | 'MANGA') => ({
			id,
			type,
			format: type === 'ANIME' ? 'TV' : 'MANGA',
			status: 'FINISHED',
			episodes: type === 'ANIME' ? 12 : null,
			chapters: null,
			seasonYear: 2023,
			title: { romaji: `R${id}`, english: `E${id}`, userPreferred: `P${id}` },
			coverImage: { large: null, color: '#336699' }
		});
		const content = createDetailContent(
			makeDetail({
				relations: {
					edges: [
						{ relationType: 'SIDE_STORY', node: node(3, 'ANIME') },
						{ relationType: 'SOURCE', node: node(1, 'MANGA') },
						{ relationType: 'PREQUEL', node: node(2, 'ANIME') }
					]
				}
			})
		);
		expect(content.relations.map((r) => [r.relation, r.title, r.meta])).toEqual([
			['Source', 'P1', 'Manga · 2023'],
			['Prequel', 'P2', 'TV · 12 eps · 2023'],
			['Side story', 'P3', 'TV · 12 eps · 2023']
		]);
		expect(content.relations[0].color).toBe('#B9A9FF');
		expect(content.relations[0].cover).toContain('linear-gradient');
	});

	it("puts an anime's novel or manga first even when AniList files it as an adaptation", () => {
		const node = (id: number, type: 'ANIME' | 'MANGA', format: string, year: number) => ({
			id,
			type,
			format,
			status: 'FINISHED',
			episodes: null,
			chapters: null,
			seasonYear: null,
			startDate: { year, month: 1, day: 1 },
			title: { romaji: `R${id}`, english: `E${id}`, userPreferred: `P${id}` },
			coverImage: { large: null, color: null }
		});
		// Kusuriya no Hitorigoto's edges, as AniList sends them
		const content = createDetailContent(
			makeDetail({
				relations: {
					edges: [
						{ relationType: 'ALTERNATIVE', node: node(4, 'MANGA', 'MANGA', 2017) },
						{ relationType: 'SEQUEL', node: node(3, 'ANIME', 'TV', 2026) },
						{ relationType: 'SIDE_STORY', node: node(5, 'ANIME', 'ONA', 2023) },
						{ relationType: 'SEQUEL', node: node(2, 'ANIME', 'TV', 2025) },
						{ relationType: 'ADAPTATION', node: node(1, 'MANGA', 'NOVEL', 2014) }
					]
				}
			})
		);
		expect(content.relations.map((r) => [r.relation, r.title])).toEqual([
			['Source', 'P1'],
			['Sequel', 'P2'],
			['Sequel', 'P3'],
			['Side story', 'P5'],
			['Alternative', 'P4']
		]);
	});

	it('maps characters with their voice actor, recommendations and the trailer', () => {
		const content = createDetailContent(
			makeDetail({
				characters: {
					edges: [
						{
							role: 'MAIN',
							node: person(10, 'Frieren'),
							voiceActors: [person(20, 'Atsumi Tanezaki')]
						}
					]
				},
				recommendations: {
					nodes: [{ mediaRecommendation: makeMedia({ id: 99 }) }, { mediaRecommendation: null }]
				},
				trailer: { id: 'abc', site: 'youtube', thumbnail: 'https://i.ytimg.com/x.jpg' }
			})
		);
		expect(content.characters[0]).toMatchObject({
			name: 'Frieren',
			role: 'Main',
			voice: { name: 'Atsumi Tanezaki' }
		});
		expect(content.recommendations.map((t) => t.id)).toEqual([99]);
		expect(content.trailer).toEqual({
			url: 'https://www.youtube.com/watch?v=abc',
			thumbnail: 'https://i.ytimg.com/x.jpg'
		});
	});

	it('carries the viewer’s entry onto the title', () => {
		const entry = {
			id: 7,
			mediaId: 1,
			status: 'CURRENT' as const,
			progress: 5,
			progressVolumes: null,
			score: 9,
			repeat: 0,
			notes: null,
			private: false,
			startedAt: { year: null, month: null, day: null },
			completedAt: { year: null, month: null, day: null }
		};
		const content = createDetailContent(makeDetail({ mediaListEntry: entry, isFavourite: true }));
		expect(content.title.me).toMatchObject({ s: 'CURRENT', p: 5 });
		expect(content.entry).toBe(entry);
		expect(content.isFavourite).toBe(true);
	});

	it('ranks tags, flags spoilers and keeps 18+ tags for accounts that show them', () => {
		const tag = (name: string, rank: number, extra: Partial<DetailMedia['tags'][number]> = {}) => ({
			id: rank,
			name,
			rank,
			description: null,
			isMediaSpoiler: false,
			isGeneralSpoiler: false,
			isAdult: false,
			...extra
		});
		const media = makeDetail({
			tags: [
				tag('Magic', 80),
				tag('Travel', 96),
				tag('Time Skip', 82, { isMediaSpoiler: true }),
				tag('Tragedy', 70, { isGeneralSpoiler: true }),
				tag('Nudity', 40, { isAdult: true })
			]
		});
		const shown = createDetailContent(media).tags;
		expect(shown.map((t) => [t.name, t.rank, t.spoiler])).toEqual([
			['Travel', 96, false],
			['Time Skip', 82, true],
			['Magic', 80, false],
			['Tragedy', 70, true]
		]);
		expect(createDetailContent(media, { adult: true }).tags.map((t) => t.name)).toContain('Nudity');
	});

	it('splits links into where to watch and the rest, safe ones only', () => {
		const link = (
			id: number,
			site: string,
			extra: Partial<DetailMedia['externalLinks'][number]> = {}
		) => ({
			id,
			url: `https://example.com/${id}`,
			site,
			type: 'STREAMING' as const,
			language: null,
			color: null,
			icon: null,
			notes: null,
			isDisabled: false,
			...extra
		});
		const content = createDetailContent(
			makeDetail({
				externalLinks: [
					link(1, 'MANGA Plus', { language: 'Thai' }),
					link(2, 'VIZ', { language: 'English', color: '#FF0000' }),
					link(3, 'YouTube', {
						notes: 'Muse Asia',
						icon: 'https://s4.anilist.co/icon.png',
						color: 'red;}'
					}),
					link(4, 'Gone', { isDisabled: true }),
					link(5, 'Sneaky', { url: 'javascript:alert(1)' }),
					link(6, 'Official Site', { type: 'INFO', language: 'Japanese' }),
					link(7, 'Twitter', { type: 'SOCIAL', icon: 'http://insecure.example/icon.png' })
				]
			})
		);
		// no language given first, then English, then the rest
		expect(content.watch.map((l) => [l.site, l.detail])).toEqual([
			['YouTube', 'Muse Asia'],
			['VIZ', ''],
			['MANGA Plus', 'Thai']
		]);
		expect(content.watch[0]).toMatchObject({ icon: 'https://s4.anilist.co/icon.png', color: null });
		expect(content.watch[1].color).toBe('#FF0000');
		expect(content.links.map((l) => [l.site, l.detail, l.icon])).toEqual([
			['Twitter', '', null],
			['Official Site', 'Japanese', null]
		]);
	});

	it('lists other names once, leaving out the ones the headline shows', () => {
		const content = createDetailContent(
			makeDetail({
				title: {
					romaji: 'Sousou no Frieren',
					english: 'Frieren',
					native: '葬送のフリーレン',
					userPreferred: 'Sousou no Frieren'
				},
				synonyms: ['Frieren at the Funeral', ' frieren ', 'Frieren at the Funeral', '葬送的芙莉蓮']
			})
		);
		expect(content.synonyms).toEqual(['Frieren at the Funeral', '葬送的芙莉蓮']);
	});

	it('counts names that differ only in case as one', () => {
		const content = createDetailContent(
			makeDetail({
				title: {
					romaji: 'ONE PIECE',
					english: 'One Piece',
					native: 'ONE PIECE',
					userPreferred: null
				}
			}),
			{ titles: 'english' }
		);
		expect(content.title.title).toBe('One Piece');
		expect(content.altTitles).toBe('');
	});
});
