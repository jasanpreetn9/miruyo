import { adaptMedia, type AdaptOptions } from '#lib/anilist/adapt.ts';
import type {
	AniListMedia,
	AniListMediaListEntry,
	HomeFeedResponse,
	MediaListStatus
} from '#lib/anilist/types.ts';
import { newEpisodesFor } from '#lib/catalog/progress.ts';
import { reasonFor, type Pick } from '#lib/page-data/for-you.ts';
import type { UpcomingItem } from '#lib/components/home/UpcomingRow.svelte';
import type { Title } from '#lib/catalog/types.ts';
import type { Mode } from '#lib/state/session.svelte.ts';

/** The viewer's current status/progress for a title, if changed locally. */
export type LocalEntry = { status: MediaListStatus; progress: number } | undefined;

/** One title in Continue's list. */
export interface ContinueItem {
	id: number;
	title: Title;
	status: MediaListStatus;
	progress: number;
	progLabel: string;
	/** "3 new · EP 9 / 24", or just where you are. */
	sub: string;
	subColor: string;
	/** Caught up and waiting for the next episode (or, on Planning, the premiere): the row shows its countdown. */
	waiting: boolean;
}

/** The viewer's own section of Home — built from HOME_LIST_QUERY. */
export interface ContinueContent {
	continueHeading: string;
	/** "3 new episodes · 2 airing this week". */
	summary: string;
	/** Green when there's something new to watch. */
	summaryFresh: boolean;
	/** Everything in progress: ready first, then waiting (Paused are in `paused`). */
	continueItems: ContinueItem[];
	/** Caught up on everything: the next to air on your list leads Continue. */
	caughtUp: ContinueItem | null;
	paused: Title[];
	/** Planning that's out, first few by priority: what to start next. */
	upNext: ContinueItem[];
}

/** The discovery rows — built from HOME_FEED_QUERY. */
export interface FeedContent {
	trendingTitles: Title[];
	popularHeading: string;
	popularSubtitle: string;
	popularTitles: Title[];
	upcomingHeading: string;
	upcomingItems: UpcomingItem[];
}

export function continueHeading(mode: Mode): string {
	return mode === 'anime' ? 'Continue watching' : 'Continue reading';
}

/** Continue, planned. */
export interface ContinuePlan<T> {
	/** Something to watch now, the most new episodes first. */
	ready: T[];
	/** Caught up and still airing, the soonest to air first. */
	waiting: T[];
	paused: T[];
	/** Aired episodes not watched yet, across what's in progress (not Paused). */
	newEpisodes: number;
	/** Titles in progress with an episode airing in the next 7 days. */
	airingThisWeek: number;
}

/**
 * What's ready first (the most new episodes first), then caught-up titles by
 * which airs soonest, Paused last. `items` arrive most recently updated
 * first, which breaks ties. `now` is unix seconds.
 */
export function planContinue<T extends { title: Title; status: MediaListStatus; progress: number }>(
	items: T[],
	now: number
): ContinuePlan<T> {
	const fresh = (i: T) => newEpisodesFor(i.title, i.progress);
	const isWaiting = (i: T) => fresh(i) === 0 && !!i.title.next;
	// Watching and Rewatching; anything moved off them this visit (completed,
	// dropped) leaves Continue, and Undo brings it back
	const active = items.filter((i) => i.status === 'CURRENT' || i.status === 'REPEATING');
	// most new first; unknown (no schedule) after any with new episodes, in update order
	const ready = active
		.filter((i) => !isWaiting(i))
		.map((item, index) => ({ item, index }))
		.sort((a, b) => (fresh(b.item) ?? 0) - (fresh(a.item) ?? 0) || a.index - b.index)
		.map(({ item }) => item);
	const waiting = active
		.filter(isWaiting)
		.sort((a, b) => (a.title.next?.at ?? Infinity) - (b.title.next?.at ?? Infinity));
	return {
		ready,
		waiting,
		paused: items.filter((i) => i.status === 'PAUSED'),
		newEpisodes: active.reduce((sum, i) => sum + (fresh(i) ?? 0), 0),
		airingThisWeek: active.filter((i) => i.title.next?.at && i.title.next.at - now <= 7 * 86400)
			.length
	};
}

/**
 * "3 new episodes · 2 airing this week". Caught up, the section's own strip
 * says so, so the summary doesn't too.
 */
export function continueSummary(plan: ContinuePlan<unknown>, isAnime: boolean): string {
	const unit = isAnime ? 'episode' : 'chapter';
	return [
		plan.newEpisodes > 0 && `${plan.newEpisodes} new ${unit}${plan.newEpisodes === 1 ? '' : 's'}`,
		plan.airingThisWeek > 0 && `${plan.airingThisWeek} airing this week`
	]
		.filter(Boolean)
		.join(' · ');
}

/** "3 new · EP 9 / 24", "16 left · EP 8 / 24", or just where you are. */
function continueSub(item: Omit<ContinueItem, 'sub' | 'subColor'>): {
	sub: string;
	subColor: string;
} {
	const { title, progress, status } = item;
	const where = `${title.unit} ${progress} / ${title.total ?? '?'}`;
	if (status === 'PAUSED') return { sub: where, subColor: 'var(--color-dim)' };
	const fresh = newEpisodesFor(title, progress);
	if (fresh) {
		return { sub: `${fresh} ${title.next ? 'new' : 'left'} · ${where}`, subColor: '#4ED98A' };
	}
	return { sub: where, subColor: item.waiting ? 'var(--color-dim)' : 'var(--color-muted)' };
}

/**
 * Builds Continue from one plan: everything in progress, what's
 * ready first (the most new first). `localEntry` overlays edits made this
 * visit (the shared list store); `now` is unix seconds.
 */
export function createContinueContent(
	mediaList: AniListMediaListEntry[],
	mode: Mode,
	localEntry: (mediaId: number) => LocalEntry = () => undefined,
	now: number = Math.floor(Date.now() / 1000),
	/** Planning entries (HOME_LIST_QUERY's upNext); one started this visit joins Continue. */
	upNextList: AniListMediaListEntry[] = []
): ContinueContent {
	const isAnime = mode === 'anime';
	const seen = new Set(mediaList.map((e) => e.media.id));
	const all = [...mediaList, ...upNextList.filter((e) => !seen.has(e.media.id))];
	const items = all.map((entry) => {
		const title = adaptMedia(entry.media, entry);
		const local = localEntry(title.id);
		return {
			entry,
			title,
			status: local?.status ?? entry.status,
			progress: local?.progress ?? entry.progress
		};
	});
	const plan = planContinue(items, now);
	const waitingIds = new Set(plan.waiting.map((i) => i.title.id));
	const toItem = (i: (typeof items)[number]): ContinueItem => {
		const base = {
			id: i.title.id,
			title: i.title,
			status: i.status,
			progress: i.progress,
			progLabel: `${i.title.unit} ${i.progress} / ${i.title.total ?? '?'}`,
			waiting: waitingIds.has(i.title.id)
		};
		return { ...base, ...continueSub(base) };
	};
	const caughtUp = plan.ready.length === 0 && plan.waiting.length > 0;
	const lead = caughtUp ? plan.waiting[0] : null;

	return {
		continueHeading: continueHeading(mode),
		summary: continueSummary(plan, isAnime),
		summaryFresh: plan.newEpisodes > 0,
		continueItems: [...plan.ready, ...plan.waiting].filter((i) => i !== lead).map(toItem),
		caughtUp: lead ? toItem(lead) : null,
		paused: plan.paused.map((i) => i.title),
		upNext: items.filter(isStartable).slice(0, UP_NEXT_SHOWN).map(toUpNext)
	};
}

/** How many Planning titles Up next offers. */
export const UP_NEXT_SHOWN = 4;

/**
 * Up next is for starting something now: a Planning title that's out. One
 * that isn't (it can't be started) waits in Home's Upcoming row instead.
 * HOME_LIST_QUERY asks for twelve Planning entries so that, with those left
 * out, there are still enough to fill Up next.
 */
function isStartable(i: { title: Title; status: MediaListStatus }): boolean {
	return i.status === 'PLANNING' && i.title.status !== 'Not yet released';
}

/** "Up next · TV · Fall 2026". */
function toUpNext({
	title,
	status,
	progress
}: {
	title: Title;
	status: MediaListStatus;
	progress: number;
}): ContinueItem {
	return {
		id: title.id,
		title,
		status,
		progress,
		progLabel: `${title.unit} ${progress} / ${title.total ?? '?'}`,
		sub: [title.format, title.isAnime ? title.season : null].filter(Boolean).join(' · '),
		subColor: 'var(--color-dim)',
		waiting: false
	};
}

/** One of the hero's slides: something to watch next, and why. */
export interface HeroPick {
	title: Title;
	/** "Because you rated Cowboy Bebop 9.5/10", or "Popular in Fall 2026". */
	reason: string;
	/** From For You, so "Not this" can hide it. */
	pick: boolean;
}

/** How many recommendations the hero shows. */
export const HERO_SLIDES = 5;

/**
 * The hero recommends (Home is for finding what to watch and tracking it):
 * For You's picks, what airs this season first; with no picks (signed out of
 * For You, too few ratings), the season's most popular you haven't added.
 * Picks are already off your list.
 */
export function heroPicks(
	picks: Pick[],
	popular: Title[],
	{
		season,
		fallbackReason,
		onList
	}: {
		/** "Fall 2026": a pick airing this season comes first. */
		season: string;
		/** The fallback's reason: "Popular in Fall 2026". */
		fallbackReason: string;
		onList: (title: Title) => boolean;
	}
): HeroPick[] {
	if (picks.length) {
		const now = (p: Pick) => p.title.season === season && p.title.status === 'Releasing';
		return [...picks.filter(now), ...picks.filter((p) => !now(p))]
			.slice(0, HERO_SLIDES)
			.map((p) => ({ title: p.title, reason: reasonFor(p), pick: true }));
	}
	return popular
		.filter((t) => !onList(t))
		.slice(0, HERO_SLIDES)
		.map((title) => ({ title, reason: fallbackReason, pick: false }));
}

/** Upcoming on Home: two rows of three on desktop; See all has the rest. */
export const UPCOMING_SHOWN = 6;

/** A sequel's mark at the end of its title: "2nd Season", "Season 3 Part 2", "II". */
const SEQUEL_MARK =
	/\s((?:\d+(?:st|nd|rd|th)\s+Season|Season\s+\d+)(?:\s+Part\s+\d+)?|Part\s+\d+|II|III|IV|\d+)$/i;

/**
 * A long sequel's title shortened in the middle, so the part that says which
 * season it is survives: "Sekai Saikou no Ansatsusha, Isekai… 2nd Season".
 * Anything else is left for the card to clamp.
 */
export function shortTitle(title: string, max = 52): string {
	if (title.length <= max) return title;
	const mark = title.match(SEQUEL_MARK)?.[1];
	if (!mark) return title;
	const head = title
		.slice(0, max - mark.length - 2)
		.replace(/\s+\S*$/, '')
		.replace(/[\s,:;\-–]+$/, '');
	return `${head}… ${mark}`;
}

/**
 * Builds the discovery rows. Each title carries the viewer's own list entry
 * (attached by HOME_FEED_QUERY), so cards show list state for every title.
 */
export function createFeedContent(
	feed: HomeFeedResponse,
	mode: Mode,
	options: AdaptOptions = {}
): FeedContent {
	const isAnime = mode === 'anime';
	const adapt = (media: AniListMedia) => adaptMedia(media, undefined, options);
	const popularTitles = feed.popularThisSeason.media.map(adapt);
	// the ones with a premiere date first, soonest first; the rest in AniList's popularity order
	const upcoming = feed.upcoming.media.map(adapt);
	const upcomingTitles = [
		...upcoming.filter((t) => t.next?.at != null).sort((a, b) => a.next!.at! - b.next!.at!),
		...upcoming.filter((t) => t.next?.at == null)
	].slice(0, UPCOMING_SHOWN);

	return {
		trendingTitles: feed.trending.media.map(adapt),
		popularHeading: isAnime ? 'Popular this season' : 'Popular releasing',
		popularSubtitle: isAnime ? (popularTitles[0]?.season ?? 'This season') : 'Updated weekly',
		popularTitles,
		upcomingHeading: isAnime ? 'Upcoming' : 'Newly serialized',
		upcomingItems: upcomingTitles.map((title) => ({
			id: title.id,
			title,
			name: shortTitle(title.title),
			when: title.season ?? 'Date TBA',
			// a format AniList hasn't announced isn't worth saying
			by: isAnime
				? [title.format === 'Unknown' ? null : title.format, title.studio]
						.filter(Boolean)
						.join(' · ')
				: (title.author ?? ''),
			// only once AniList has a date; until then the season says when
			cd: title.next ? `Premieres in ${title.next.in}` : null
		}))
	};
}
