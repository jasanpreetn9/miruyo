import { describe, expect, it } from 'vitest';
import { makeCollectionEntry, makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import type { AniListMedia } from '#lib/anilist/types.ts';
import {
	buildPicks,
	DEFAULT_TUNE,
	favouriteStudios,
	localDay,
	MAX_SEEDS,
	pickGenres,
	pickSeeds,
	reasonFor,
	scoredCount,
	tunePicks,
	type Recommendation,
	type Relation,
	type Seed
} from './for-you.ts';

const titled = (id: number, name: string, extra: Partial<AniListMedia> = {}) =>
	makeMedia({
		id,
		title: { romaji: name, english: name, native: null, userPreferred: name },
		...extra
	});

// scores are on the 10-point decimal scale here
const frieren = makeCollectionEntry(titled(1, 'Frieren', { genres: ['Fantasy'] }), {
	status: 'COMPLETED',
	score: 9.5
});
const apothecary = makeCollectionEntry(titled(2, 'Apothecary', { genres: ['Mystery'] }), {
	status: 'COMPLETED',
	score: 9
});
const meh = makeCollectionEntry(titled(3, 'Meh'), { status: 'COMPLETED', score: 5 });
const planned = makeCollectionEntry(titled(4, 'Planned'), { status: 'PLANNING', score: 0 });
const entries = [frieren, apothecary, meh, planned];

const opts = {
	entries,
	scoreFormat: 'POINT_10_DECIMAL' as const,
	type: 'ANIME' as const,
	showAdult: false,
	dismissed: new Set<number>()
};

describe('pickSeeds', () => {
	it('takes the highest rated titles, best first', () => {
		const seeds = pickSeeds(entries, 'POINT_10_DECIMAL');
		expect(seeds.map((s) => [s.title, s.score])).toEqual([
			['Frieren', 9.5],
			['Apothecary', 9]
		]);
	});

	it('reads any score format', () => {
		const onHundred = makeCollectionEntry(titled(9, 'Hundred'), { status: 'COMPLETED', score: 90 });
		expect(pickSeeds([onHundred], 'POINT_100')[0].score).toBe(9);
	});

	it('counts scored titles', () => {
		expect(scoredCount(entries)).toBe(3);
	});

	it('ranks by the exact score, rounding only what it shows', () => {
		const bebop = makeCollectionEntry(titled(20, 'Bebop'), { status: 'COMPLETED', score: 9.7 });
		const fate = makeCollectionEntry(titled(21, 'Fate'), {
			status: 'COMPLETED',
			score: 9.5,
			updatedAt: bebop.updatedAt + 100
		});
		expect(pickSeeds([fate, bebop], 'POINT_10_DECIMAL').map((s) => [s.title, s.score])).toEqual([
			['Bebop', 9.5],
			['Fate', 9.5]
		]);
	});

	describe('rotating by day', () => {
		// 30 titles rated 7.5 to 10
		const many = Array.from({ length: 30 }, (_, i) =>
			makeCollectionEntry(titled(100 + i, `T${i}`), {
				status: 'COMPLETED',
				score: 7.5 + (i % 6) * 0.5
			})
		);
		const ids = (day: string) => pickSeeds(many, 'POINT_10_DECIMAL', day).map((s) => s.id);

		it('draws MAX_SEEDS, the same all day, best first', () => {
			const seeds = pickSeeds(many, 'POINT_10_DECIMAL', '2026-11-02');
			expect(seeds).toHaveLength(MAX_SEEDS);
			expect(ids('2026-11-02')).toEqual(seeds.map((s) => s.id));
			const scores = seeds.map((s) => s.score);
			expect(scores).toEqual([...scores].sort((a, b) => b - a));
		});

		it('draws a different set on other days', () => {
			const week = ['01', '02', '03', '04', '05', '06', '07'].map((d) =>
				ids(`2026-11-${d}`).join()
			);
			expect(new Set(week).size).toBeGreaterThan(5);
		});

		it('brings the higher rated round more often', () => {
			const seen = new Map<number, number>();
			for (let d = 1; d <= 200; d++) {
				for (const id of ids(`day-${d}`)) seen.set(id, (seen.get(id) ?? 0) + 1);
			}
			const at = (score: number) =>
				many
					.filter((e) => e.score === score)
					.reduce((sum, e) => sum + (seen.get(e.media.id) ?? 0), 0);
			expect(at(10)).toBeGreaterThan(at(7.5) * 2);
		});

		it('keeps every title when there are no more than MAX_SEEDS', () => {
			expect(pickSeeds(entries, 'POINT_10_DECIMAL', '2026-11-02').map((s) => s.title)).toEqual([
				'Frieren',
				'Apothecary'
			]);
		});
	});

	it('names the day in local time', () => {
		expect(localDay(new Date(2026, 0, 5, 23, 59))).toBe('2026-01-05');
	});
});

describe('buildPicks', () => {
	const seeds = pickSeeds(entries, 'POINT_10_DECIMAL');
	const rec = (media: AniListMedia, rating: number): Recommendation => ({ rating, media });

	it('ranks titles recommended by more and better-rated seeds first, with a reason', () => {
		const both = titled(10, 'Both');
		const one = titled(11, 'One');
		const recs = new Map([
			[1, [rec(both, 50), rec(one, 50)]],
			[2, [rec(both, 10)]]
		]);
		const picks = buildPicks(seeds, recs, opts);
		expect(picks.map((p) => p.title.id)).toEqual([10, 11]);
		expect(picks[0].seedIds).toEqual([1, 2]);
		expect(reasonFor(picks[0])).toBe('Because you rated Frieren 9.5/10');
	});

	it('leaves out titles on the list, dismissed, adult, or of the other type', () => {
		const recs = new Map([
			[
				1,
				[
					rec(titled(2, 'Apothecary'), 99), // already on the list
					rec(titled(20, 'Dismissed'), 99),
					rec(titled(21, 'Adult', { isAdult: true }), 99),
					rec(makeManga({ id: 22 }), 99),
					rec(
						titled(23, 'Listed elsewhere', {
							mediaListEntry: { id: 1, status: 'PLANNING', progress: 0 }
						}),
						99
					),
					rec(titled(24, 'Fresh'), 1)
				]
			]
		]);
		const picks = buildPicks(seeds, recs, { ...opts, dismissed: new Set([20]) });
		expect(picks.map((p) => p.title.id)).toEqual([24]);
	});

	it('nudges up titles in genres you rate highly', () => {
		const fantasy = titled(30, 'Fantasy pick', { genres: ['Fantasy'] });
		const other = titled(31, 'Other pick', { genres: ['Sports'] });
		const recs = new Map([[2, [rec(other, 5), rec(fantasy, 5)]]]);
		expect(buildPicks(seeds, recs, opts).map((p) => p.title.id)).toEqual([30, 31]);
	});
});

const studio = (id: number, name: string) => ({ nodes: [{ id, name, siteUrl: null }] });

describe('studios', () => {
	const madhouse = studio(11, 'MADHOUSE');
	const loved = (id: number, s = madhouse, score = 9) =>
		makeCollectionEntry(titled(id, `Loved ${id}`, { studios: s }), { status: 'COMPLETED', score });

	it('counts a studio once two titles it made are rated 7.5 or more', () => {
		expect(favouriteStudios([loved(1), loved(2)], 'POINT_10_DECIMAL')).toEqual(
			new Map([[11, 'MADHOUSE']])
		);
		// one title isn't a pattern; a low score doesn't count
		expect(favouriteStudios([loved(1), loved(2, madhouse, 6)], 'POINT_10_DECIMAL').size).toBe(0);
	});

	it("lifts a favourite studio's pick and says which studio", () => {
		const list = [loved(1), loved(2)];
		const seeds = pickSeeds(list, 'POINT_10_DECIMAL');
		const recs = new Map<number, Recommendation[]>([
			[
				1,
				[
					{ rating: 40, media: titled(10, 'Other', { studios: studio(12, 'Other') }) },
					{ rating: 40, media: titled(11, 'Mad', { studios: madhouse }) }
				]
			]
		]);
		const picks = buildPicks(seeds, recs, { ...opts, entries: list });
		expect(picks.map((p) => [p.title.id, p.studio?.name ?? null])).toEqual([
			[11, 'MADHOUSE'],
			[10, null]
		]);
		expect(picks[0].score).toBeCloseTo(picks[1].score * 1.15);
	});
});

describe('across modes', () => {
	const anime = (id: number, name: string): Seed => ({
		id,
		title: name,
		cover: '',
		score: 9,
		type: 'ANIME'
	});
	const manga = (id: number, name: string, extra: Partial<AniListMedia> = {}) =>
		makeManga({
			id,
			title: { romaji: name, english: name, native: null, userPreferred: name },
			...extra
		});
	const mangaOpts = { ...opts, entries: [], type: 'MANGA' as const };

	it("suggests an anime's source manga, saying why", () => {
		const relations = new Map<number, Relation[]>([
			[
				1,
				[
					{ relationType: 'SOURCE', media: manga(100, 'Frieren (manga)') },
					{ relationType: 'SEQUEL', media: manga(101, 'Not this one') }
				]
			]
		]);
		const picks = buildPicks([], new Map(), {
			...mangaOpts,
			crossSeeds: [anime(1, 'Frieren')],
			relations
		});
		expect(picks.map((p) => p.title.id)).toEqual([100]);
		expect(picks[0].kind).toBe('adaptation');
		expect(reasonFor(picks[0])).toBe('The manga of Frieren, which you rated 9/10');
	});

	it("takes a manga's two most popular anime, and calls a novel a novel", () => {
		const seed: Seed = { id: 2, title: 'Berserk', cover: '', score: 10, type: 'MANGA' };
		const show = (id: number, popularity: number) =>
			({ ...titled(id, `Berserk ${id}`), popularity }) as AniListMedia;
		const relations = new Map<number, Relation[]>([
			[
				2,
				[
					{ relationType: 'ADAPTATION', media: show(200, 10) },
					{ relationType: 'ADAPTATION', media: show(201, 300) },
					{ relationType: 'ADAPTATION', media: show(202, 200) }
				]
			]
		]);
		const picks = buildPicks([], new Map(), {
			...opts,
			entries: [],
			crossSeeds: [seed],
			relations
		});
		expect(picks.map((p) => p.title.id).sort()).toEqual([201, 202]);
		expect(reasonFor(picks[0])).toBe('The anime of Berserk, which you rated 10/10');

		const novel = buildPicks([], new Map(), {
			...mangaOpts,
			crossSeeds: [anime(3, 'Spice and Wolf')],
			relations: new Map([
				[3, [{ relationType: 'SOURCE', media: manga(300, 'Spice and Wolf', { format: 'NOVEL' }) }]]
			])
		});
		expect(reasonFor(novel[0])).toBe('The novel of Spice and Wolf, which you rated 9/10');
	});

	it('leaves out what is already on the list', () => {
		const relations = new Map<number, Relation[]>([
			[1, [{ relationType: 'SOURCE', media: manga(100, 'On my list') }]]
		]);
		const onList = makeCollectionEntry(manga(100, 'On my list'), { status: 'CURRENT', score: 0 });
		expect(
			buildPicks([], new Map(), {
				...mangaOpts,
				entries: [onList],
				crossSeeds: [anime(1, 'Frieren')],
				relations
			})
		).toEqual([]);
	});
});

describe('tunePicks', () => {
	const seed: Seed = { id: 1, title: 'Seed', cover: '', score: 9, type: 'ANIME' };
	const recs = new Map<number, Recommendation[]>([
		[
			1,
			[
				{ rating: 9, media: titled(10, 'Out', { genres: ['Action'], status: 'FINISHED' }) },
				{ rating: 9, media: titled(11, 'Soon', { genres: ['Drama'], status: 'NOT_YET_RELEASED' }) }
			]
		]
	]);
	const crossSeed: Seed = { id: 2, title: 'Manga', cover: '', score: 9, type: 'MANGA' };
	const relations = new Map<number, Relation[]>([
		[2, [{ relationType: 'ADAPTATION', media: titled(12, 'Its anime', { genres: ['Drama'] }) }]]
	]);
	const picks = buildPicks([seed], recs, {
		...opts,
		entries: [],
		crossSeeds: [crossSeed],
		relations
	});
	const ids = (p: typeof picks) => p.map((x) => x.title.id).sort();

	it('keeps everything by default', () => {
		expect(ids(tunePicks(picks, DEFAULT_TUNE))).toEqual([10, 11, 12]);
	});

	it('leaves out what is not out yet, the other mode, or a genre', () => {
		expect(ids(tunePicks(picks, { ...DEFAULT_TUNE, outOnly: true }))).toEqual([10, 12]);
		expect(ids(tunePicks(picks, { ...DEFAULT_TUNE, crossMode: false }))).toEqual([10, 11]);
		expect(ids(tunePicks(picks, { ...DEFAULT_TUNE, hiddenGenres: ['Drama'] }))).toEqual([10]);
	});

	it('offers the genres among the picks, most common first', () => {
		expect(pickGenres(picks)).toEqual(['Drama', 'Action']);
	});
});
