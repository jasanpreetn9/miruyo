import { describe, expect, it } from 'vitest';
import { makeEntry, makeHomeFeed, makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import { adaptMedia } from '#lib/anilist/adapt.ts';
import type { Pick } from './for-you.ts';
import {
	createContinueContent,
	createFeedContent,
	heroPicks,
	shortTitle,
	UPCOMING_SHOWN
} from './home.ts';

const noOverride = () => undefined;

describe('createContinueContent', () => {
	const NOW = 1_000_000;
	const airing = (episode: number, inSeconds = 86400) => ({
		nextAiringEpisode: { episode, airingAt: NOW + inSeconds, timeUntilAiring: inSeconds }
	});

	it('is empty when nothing is in progress', () => {
		const content = createContinueContent([], 'anime', noOverride, NOW);
		expect(content.continueItems).toEqual([]);
		expect(content.caughtUp).toBeNull();
		expect(content.continueHeading).toBe('Continue watching');
	});

	it('lists everything in progress, the most to watch first, then the waiting', () => {
		const entries = [1, 2, 3, 4, 5].map((id) =>
			makeEntry(makeMedia({ id, ...airing(10) }), { progress: id })
		);
		const waiting = makeEntry(makeMedia({ id: 6, ...airing(4) }), { progress: 3 });
		const content = createContinueContent([...entries, waiting], 'anime', noOverride, NOW);
		// progress 1 has 8 new, progress 5 has 4
		expect(content.continueItems.map((i) => i.id)).toEqual([1, 2, 3, 4, 5, 6]);
		expect(content.continueItems[0]).toMatchObject({ sub: '8 new · EP 1 / 24', waiting: false });
		expect(content.continueItems[5].waiting).toBe(true);
		expect(content.summary).toBe('30 new episodes · 6 airing this week');
		expect(content.summaryFresh).toBe(true);
	});

	it('says what is left of something finished', () => {
		const media = makeMedia({ status: 'FINISHED' });
		const home = createContinueContent(
			[makeEntry(media), makeEntry(makeMedia({ id: 2, status: 'FINISHED' }), { progress: 20 })],
			'anime',
			noOverride,
			NOW
		);
		expect(home.continueItems.map((i) => i.sub)).toEqual([
			'19 left · EP 5 / 24',
			'4 left · EP 20 / 24'
		]);
	});

	it("leads with You're caught up when nothing is ready", () => {
		const soon = makeEntry(makeMedia({ id: 1, ...airing(6, 3600) }), { progress: 5 });
		const later = makeEntry(makeMedia({ id: 2, ...airing(3, 7200) }), { progress: 2 });
		const home = createContinueContent([later, soon], 'anime', noOverride, NOW);
		expect(home.caughtUp?.id).toBe(1);
		expect(home.continueItems.map((i) => i.id)).toEqual([2]);
		expect(home.continueItems[0]).toMatchObject({ waiting: true, sub: 'EP 2 / 24' });
		// the strip says caught up; the summary doesn't repeat it
		expect(home.summary).toBe('2 airing this week');
	});

	it('folds Paused titles into their own line', () => {
		const home = createContinueContent(
			[makeEntry(makeMedia({ id: 1 }), { status: 'PAUSED' }), makeEntry(makeMedia({ id: 2 }))],
			'anime',
			noOverride,
			NOW
		);
		expect(home.paused.map((t) => t.id)).toEqual([1]);
		expect(home.continueItems.map((i) => i.id)).toEqual([2]);
	});

	it('applies local list changes to the continue items', () => {
		const media = makeMedia();
		const home = createContinueContent(
			[makeEntry(media, { progress: 5 })],
			'anime',
			(id) => (id === media.id ? { status: 'REPEATING', progress: 6 } : undefined),
			NOW
		);
		expect(home.continueItems[0]).toMatchObject({ status: 'REPEATING', progLabel: 'EP 6 / 24' });
	});

	it('drops an entry completed this visit', () => {
		const home = createContinueContent([makeEntry(makeMedia(), { progress: 24 })], 'anime', () => ({
			status: 'COMPLETED',
			progress: 24
		}));
		expect(home.continueItems).toEqual([]);
	});

	it('lists Planning as Up next, and a title started this visit joins Continue', () => {
		const watching = makeEntry(makeMedia({ id: 1 }), { progress: 5 });
		const planned = makeEntry(makeMedia({ id: 2 }), { status: 'PLANNING', progress: 0 });
		const home = createContinueContent([watching], 'anime', noOverride, NOW, [planned]);
		expect(home.upNext.map((i) => [i.id, i.sub, i.waiting])).toEqual([
			[2, 'TV · Fall 2026', false]
		]);

		const started = createContinueContent(
			[watching],
			'anime',
			(id) => (id === 2 ? { status: 'CURRENT', progress: 1 } : undefined),
			NOW,
			[planned]
		);
		expect(started.upNext).toEqual([]);
		expect(started.continueItems.map((i) => i.id)).toEqual([1, 2]);
	});

	it("leaves titles that aren't out yet out of Up next, still showing four", () => {
		const plan = (id: number, status = 'FINISHED') =>
			makeEntry(makeMedia({ id, status: status as 'FINISHED' }), {
				status: 'PLANNING',
				progress: 0
			});
		const home = createContinueContent([], 'anime', noOverride, NOW, [
			plan(1, 'NOT_YET_RELEASED'),
			plan(2),
			plan(3, 'RELEASING'),
			plan(4, 'NOT_YET_RELEASED'),
			plan(5),
			plan(6),
			plan(7)
		]);
		// in priority order, the unreleased skipped, and no more than four
		expect(home.upNext.map((i) => i.id)).toEqual([2, 3, 5, 6]);
	});

	it('uses the chapter total for manga when known', () => {
		const manga = makeManga({ chapters: 120 });
		const home = createContinueContent(
			[makeEntry(manga, { progress: 40 })],
			'manga',
			noOverride,
			NOW
		);
		expect(home.continueItems[0].progLabel).toBe('CH 40 / 120');
		expect(home.continueHeading).toBe('Continue reading');
	});
});

describe('heroPicks', () => {
	const title = (id: number, extra = {}) => adaptMedia(makeMedia({ id, ...extra }));
	const pick = (id: number, extra = {}): Pick => ({
		title: title(id, extra),
		because: { id: 99, title: 'Cowboy Bebop', score: 9.5, cover: '' } as Pick['because'],
		seedIds: [99],
		score: 1,
		kind: 'recommended',
		studio: null
	});
	const opts = { season: 'Fall 2026', fallbackReason: 'Popular in Fall 2026', onList: () => false };

	it('recommends For You picks, what airs this season first, with the reason', () => {
		const old = pick(1, { status: 'FINISHED', season: 'SPRING', seasonYear: 2011 });
		const airing = pick(2, { status: 'RELEASING', season: 'FALL', seasonYear: 2026 });
		const slides = heroPicks([old, airing], [title(3)], opts);
		expect(slides.map((s) => [s.title.id, s.pick])).toEqual([
			[2, true],
			[1, true]
		]);
		expect(slides[0].reason).toBe('Because you rated Cowboy Bebop 9.5/10');
	});

	it('shows at most five', () => {
		expect(
			heroPicks(
				[1, 2, 3, 4, 5, 6, 7].map((id) => pick(id)),
				[],
				opts
			)
		).toHaveLength(5);
	});

	it("falls back to the season's most popular not on your list", () => {
		const slides = heroPicks([], [title(1), title(2)], { ...opts, onList: (t) => t.id === 1 });
		expect(slides).toEqual([{ title: title(2), reason: 'Popular in Fall 2026', pick: false }]);
	});
});

describe('createFeedContent', () => {
	it('shows list state from the entry each title carries', () => {
		const onList = makeMedia({
			id: 1,
			mediaListEntry: { id: 10, status: 'PLANNING', progress: 0 }
		});
		const notOnList = makeMedia({ id: 2, mediaListEntry: null });
		const feed = createFeedContent(makeHomeFeed({ trending: [onList, notOnList] }), 'anime');
		expect(feed.trendingTitles[0].me).toMatchObject({ s: 'PLANNING', p: 0 });
		expect(feed.trendingTitles[1].me).toBeUndefined();
	});

	it('builds upcoming items', () => {
		const upcoming = makeMedia({
			id: 3,
			status: 'NOT_YET_RELEASED',
			season: 'WINTER',
			seasonYear: 2027,
			nextAiringEpisode: { episode: 1, airingAt: 0, timeUntilAiring: 3 * 86400 }
		});
		const feed = createFeedContent(makeHomeFeed({ upcoming: [upcoming] }), 'anime');
		expect(feed.upcomingItems[0]).toMatchObject({
			when: 'Winter 2027',
			by: 'TV · Studio One',
			cd: 'Premieres in 3d'
		});
	});

	it('puts dated premieres first, soonest first, and shows six', () => {
		const dated = (id: number, days: number) =>
			makeMedia({
				id,
				status: 'NOT_YET_RELEASED',
				nextAiringEpisode: { episode: 1, airingAt: days * 86400, timeUntilAiring: days * 86400 }
			});
		const undated = (id: number) => makeMedia({ id, status: 'NOT_YET_RELEASED' });
		const feed = createFeedContent(
			makeHomeFeed({
				upcoming: [
					undated(1),
					dated(2, 75),
					undated(3),
					dated(4, 66),
					undated(5),
					undated(6),
					undated(7)
				]
			}),
			'anime'
		);
		// dated by date; the rest keep AniList's (popularity) order
		expect(feed.upcomingItems.map((i) => i.id)).toEqual([4, 2, 1, 3, 5, 6]);
		expect(feed.upcomingItems).toHaveLength(UPCOMING_SHOWN);
		expect(feed.upcomingItems[2].cd).toBeNull();
	});

	it('leaves out a format AniList has not announced', () => {
		const feed = createFeedContent(
			makeHomeFeed({ upcoming: [makeMedia({ id: 9, format: null })] }),
			'anime'
		);
		expect(feed.upcomingItems[0].by).toBe('Studio One');
	});

	it('shortens a long sequel in the middle, keeping which season it is', () => {
		expect(shortTitle('Sekai Saikou no Ansatsusha, Isekai Kizoku ni Tensei suru 2nd Season')).toBe(
			'Sekai Saikou no Ansatsusha, Isekai… 2nd Season'
		);
		expect(shortTitle('One Punch Man Season 3 Part 2')).toBe('One Punch Man Season 3 Part 2');
		// no season to keep: left whole for the card to clamp
		const long =
			'MASHLE: MAGIC AND MUSCLES The Tri-Magicathlon Divine Visionary Candidate Exam Arc';
		expect(shortTitle(long)).toBe(long);
	});

	it('uses manga headings in manga mode', () => {
		const feed = createFeedContent(makeHomeFeed(), 'manga');
		expect(feed.popularHeading).toBe('Popular releasing');
		expect(feed.upcomingHeading).toBe('Newly serialized');
	});
});
