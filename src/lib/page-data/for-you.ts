import { adaptMedia } from '#lib/anilist/adapt.ts';
import type { AniListMedia, CollectionEntry, ScoreFormat } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';
import { toTenPoint } from './stats.ts';

// For You (design 08): picks scored from AniList's recommendations for
// titles you rated highly, plus a nudge toward the genres and studios you
// favour, and the other mode's take on titles you loved (the manga of an
// anime, the anime of a manga). Every pick carries the reason it was picked.
// The titles behind them rotate each day, so Home's "Because you loved …"
// rows change from one day to the next. "Tune picks" filters the result.

/** Below this many scored titles, picks aren't worth showing (design 8c). */
export const MIN_RATINGS = 5;
/** How many highly rated titles seed the picks each day. */
export const MAX_SEEDS = 8;
/**
 * What "loved" means (out of 10) until a list has enough scores to judge by
 * its own: below LOVED_FROM_RATINGS scored titles, a seed is rated 7.5 or more.
 */
const SEED_MIN_SCORE = 7.5;
/** With this many scored titles, "loved" is measured against your own scores. */
const LOVED_FROM_RATINGS = 10;
/**
 * Loved is half a deviation above your mean, kept within these: a harsh
 * rater's 7 is a high mark, but a 6.5 isn't; a generous rater's 9 is
 * ordinary, but every 9.5 still counts.
 */
const LOVED_FLOOR = 7;
const LOVED_CEILING = 9;
/**
 * A genre's lift (its mean score above your overall mean, in points) is
 * shrunk toward nothing by this many titles' worth, so one 10 in a genre
 * isn't a taste.
 */
const GENRE_SHRINK = 3;
/** Each point of genre lift moves a pick this much, within GENRE_LIMITS. */
const GENRE_WEIGHT = 0.1;
const GENRE_LIMITS = [0.7, 1.4] as const;
/** How many titles from the other list look for their manga or anime. */
export const MAX_CROSS_SEEDS = 4;
/** A cross seed suggests at most this many of its adaptations (Berserk has seven). */
const ADAPTATIONS_PER_SEED = 2;
/**
 * How much the other mode's version of a title you loved weighs, in AniList
 * votes: about as much as a well-backed recommendation.
 */
const ADAPTATION_VOTES = 30;
/** A pick from one of your favourite studios weighs this much more. */
const STUDIO_BOOST = 0.15;

export interface Seed {
	id: number;
	title: string;
	cover: string;
	/** Out of 10, e.g. 9 or 9.5. */
	score: number;
	type: 'ANIME' | 'MANGA';
}

/** One AniList recommendation of a seed: the recommended title and its votes. */
export interface Recommendation {
	rating: number;
	media: AniListMedia;
}

/** A title related to a seed (relations: SOURCE, ADAPTATION, …). */
export interface Relation {
	relationType: string;
	media: AniListMedia;
}

export interface Pick {
	title: Title;
	/** The seed that contributed most, for "Because you rated X 9/10". */
	because: Seed;
	/** Every seed that recommended it (the seed rail filters on these). */
	seedIds: number[];
	score: number;
	/** Recommended by AniList's users, or the other mode's version of a seed. */
	kind: 'recommended' | 'adaptation';
	/** One of your favourite studios made it. */
	studio: { id: number; name: string } | null;
}

/** "9/10", "9.5/10". */
export function scoreLabel(score: number): string {
	return `${Number.isInteger(score) ? score : score.toFixed(1)}/10`;
}

export function reasonFor(pick: Pick): string {
	if (pick.kind === 'adaptation') {
		const what = pick.title.isAnime
			? 'anime'
			: /novel/i.test(pick.title.format)
				? 'novel'
				: 'manga';
		return `The ${what} of ${pick.because.title}, which you rated ${scoreLabel(pick.because.score)}`;
	}
	return `Because you rated ${pick.because.title} ${scoreLabel(pick.because.score)}`;
}

const RATED_STATUSES = new Set(['COMPLETED', 'CURRENT', 'REPEATING', 'PAUSED']);

/** How many titles on the list carry a score. */
export function scoredCount(entries: CollectionEntry[]): number {
	return entries.filter((e) => e.score > 0).length;
}

/** Today in the viewer's timezone ("2026-11-02"): the seeds change with it. */
export function localDay(now = new Date()): string {
	const pad = (n: number) => String(n).padStart(2, '0');
	return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

/** A number in (0, 1) from `text`, the same every time (FNV-1a, then mixed). */
function unitHash(text: string): number {
	let h = 0x811c9dc5;
	for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 0x01000193);
	h = Math.imul(h ^ (h >>> 16), 0x85ebca6b);
	h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35);
	h ^= h >>> 16;
	return ((h >>> 0) + 1) / 4294967297;
}

/**
 * The score (out of 10) from which you loved a title. Under LOVED_FROM_RATINGS
 * scores it's 7.5; past that it's your own: half a deviation above your mean,
 * from LOVED_FLOOR to LOVED_CEILING. A harsh rater who averages 6 loves from
 * 7, a generous one who averages 9 from 9.
 */
export function lovedFrom(entries: CollectionEntry[], scoreFormat?: ScoreFormat): number {
	const scores = entries.filter((e) => e.score > 0).map((e) => toTenPoint(e.score, scoreFormat));
	if (scores.length < LOVED_FROM_RATINGS) return SEED_MIN_SCORE;
	const mean = scores.reduce((a, s) => a + s, 0) / scores.length;
	const deviation = Math.sqrt(scores.reduce((a, s) => a + (s - mean) ** 2, 0) / scores.length);
	return Math.min(LOVED_CEILING, Math.max(LOVED_FLOOR, mean + deviation / 2));
}

/**
 * The titles driving the picks: up to MAX_SEEDS you loved (lovedFrom), best
 * first (by your exact score, then most recently updated). With more than
 * that to choose from, `day` draws a different set each day: the same all
 * day, and weighted so the higher you rated a title, the more often it comes
 * round (with the 7.5 cutoff, a 10 about six times as often as a 7.5).
 * Without `day`, the top ones.
 */
export function pickSeeds(
	entries: CollectionEntry[],
	scoreFormat?: ScoreFormat,
	day?: string
): Seed[] {
	const loved = lovedFrom(entries, scoreFormat);
	const pool = entries
		.filter((e) => e.score > 0 && RATED_STATUSES.has(e.status))
		.map((e) => ({ entry: e, exact: toTenPoint(e.score, scoreFormat) }))
		.filter((s) => s.exact >= loved);
	// a weighted draw without replacement (Efraimidis–Spirakis), keyed on the
	// day; the weight is how far past the cutoff a title is, plus half a point
	const drawn =
		day && pool.length > MAX_SEEDS
			? pool
					.map((s) => ({
						s,
						key: unitHash(`${day}:${s.entry.media.id}`) ** (1 / (s.exact - loved + 0.5))
					}))
					.sort((a, b) => b.key - a.key)
					.slice(0, MAX_SEEDS)
					.map(({ s }) => s)
			: pool;
	return drawn
		.sort((a, b) => b.exact - a.exact || b.entry.updatedAt - a.entry.updatedAt)
		.slice(0, MAX_SEEDS)
		.map(({ entry, exact }) => {
			const title = adaptMedia(entry.media);
			// shown as "9.5/10": half points
			return {
				id: entry.media.id,
				title: title.title,
				cover: title.cover,
				score: Math.round(exact * 2) / 2,
				type: entry.media.type
			};
		});
}

/**
 * How much more (or less) you like each genre than your list as a whole: its
 * mean score minus your overall mean, in points, shrunk toward 0 by
 * GENRE_SHRINK titles so a genre needs a few scores to count. Action, on
 * half the list, has a lift near 0 however many you've seen; a genre you
 * score well above your usual has a high one, and one you score below it a
 * negative one.
 */
export function genreLift(
	entries: CollectionEntry[],
	scoreFormat?: ScoreFormat
): Map<string, number> {
	const scored = entries
		.filter((e) => e.score > 0)
		.map((e) => ({ genres: e.media.genres ?? [], score: toTenPoint(e.score, scoreFormat) }));
	if (!scored.length) return new Map();
	const mean = scored.reduce((a, s) => a + s.score, 0) / scored.length;
	const sums = new Map<string, { above: number; n: number }>();
	for (const s of scored) {
		for (const g of s.genres) {
			const sum = sums.get(g) ?? { above: 0, n: 0 };
			sum.above += s.score - mean;
			sum.n++;
			sums.set(g, sum);
		}
	}
	return new Map([...sums].map(([g, { above, n }]) => [g, above / (n + GENRE_SHRINK)]));
}

/** How a pick's genres move it: GENRE_WEIGHT a point of lift, within GENRE_LIMITS. */
function genreFactor(genres: string[], lift: Map<string, number>): number {
	const points = genres.reduce((a, g) => a + (lift.get(g) ?? 0), 0);
	return Math.min(GENRE_LIMITS[1], Math.max(GENRE_LIMITS[0], 1 + GENRE_WEIGHT * points));
}

/**
 * The studios behind the titles you love (lovedFrom): a studio counts once
 * two of its titles are loved. The top five, most titles first.
 */
export function favouriteStudios(
	entries: CollectionEntry[],
	scoreFormat?: ScoreFormat
): Map<number, string> {
	const loved = lovedFrom(entries, scoreFormat);
	const counts = new Map<number, { name: string; n: number }>();
	for (const e of entries) {
		if (!e.score || toTenPoint(e.score, scoreFormat) < loved) continue;
		const studio = e.media.studios?.nodes[0];
		if (!studio) continue;
		const c = counts.get(studio.id) ?? { name: studio.name, n: 0 };
		c.n++;
		counts.set(studio.id, c);
	}
	return new Map(
		[...counts.entries()]
			.filter(([, c]) => c.n >= 2)
			.sort((a, b) => b[1].n - a[1].n)
			.slice(0, 5)
			.map(([id, c]) => [id, c.name])
	);
}

/**
 * The other mode's version of a seed: an anime's source manga (or novel),
 * a manga's anime adaptations, its two most popular.
 */
function adaptationsOf(relations: Relation[], seed: Seed): AniListMedia[] {
	const wanted = seed.type === 'ANIME' ? 'SOURCE' : 'ADAPTATION';
	return relations
		.filter((r) => r.relationType === wanted && r.media.type !== seed.type)
		.map((r) => r.media)
		.sort((a, b) => (b.popularity ?? 0) - (a.popularity ?? 0))
		.slice(0, ADAPTATIONS_PER_SEED);
}

/**
 * Ranks every recommended title not already on the list. A title earns
 * weight from each seed that recommends it (the seed's score × AniList's
 * vote count, dampened; recommendations with no votes left over don't
 * count), moves up or down with how you rate its genres (genreLift), and
 * weighs more if a favourite studio made it. `crossSeeds` are titles you loved
 * on your other list; their manga or anime (`relations`) join the picks.
 */
export function buildPicks(
	seeds: Seed[],
	recommendations: Map<number, Recommendation[]>,
	{
		entries,
		scoreFormat,
		type,
		showAdult,
		dismissed,
		crossSeeds = [],
		relations = new Map()
	}: {
		entries: CollectionEntry[];
		scoreFormat?: ScoreFormat;
		type: 'ANIME' | 'MANGA';
		showAdult: boolean;
		dismissed: Set<number>;
		crossSeeds?: Seed[];
		relations?: Map<number, Relation[]>;
	}
): Pick[] {
	const onList = new Set(entries.map((e) => e.media.id));
	const lift = genreLift(entries, scoreFormat);
	const studios = favouriteStudios(entries, scoreFormat);
	const byId = new Map<
		number,
		{
			media: AniListMedia;
			score: number;
			best: number;
			because: Seed;
			seedIds: number[];
			kind: Pick['kind'];
		}
	>();

	function add(media: AniListMedia, seed: Seed, weight: number, kind: Pick['kind']) {
		if (media.type !== type || onList.has(media.id) || dismissed.has(media.id)) return;
		if (media.mediaListEntry || (media.isAdult && !showAdult)) return;
		const pick = byId.get(media.id);
		if (!pick) {
			byId.set(media.id, {
				media,
				score: weight,
				best: weight,
				because: seed,
				seedIds: [seed.id],
				kind
			});
			return;
		}
		pick.score += weight;
		if (!pick.seedIds.includes(seed.id)) pick.seedIds.push(seed.id);
		if (weight > pick.best) {
			pick.best = weight;
			pick.because = seed;
			pick.kind = kind;
		}
	}

	for (const seed of seeds) {
		for (const { rating, media } of recommendations.get(seed.id) ?? []) {
			// a recommendation AniList's users voted to nothing (or below) isn't one
			if (rating <= 0) continue;
			add(media, seed, (seed.score / 10) * Math.log2(2 + rating), 'recommended');
		}
	}
	for (const seed of crossSeeds) {
		for (const media of adaptationsOf(relations.get(seed.id) ?? [], seed)) {
			add(media, seed, (seed.score / 10) * Math.log2(2 + ADAPTATION_VOTES), 'adaptation');
		}
	}

	return [...byId.values()]
		.map((p) => {
			const main = p.media.studios?.nodes[0];
			const studio = main && studios.has(main.id) ? { id: main.id, name: main.name } : null;
			return {
				title: adaptMedia(p.media),
				because: p.because,
				seedIds: p.seedIds,
				kind: p.kind,
				studio,
				score: p.score * genreFactor(p.media.genres ?? [], lift) * (studio ? 1 + STUDIO_BOOST : 1)
			};
		})
		.sort((a, b) => b.score - a.score || a.title.id - b.title.id);
}

/** "Tune picks": what to leave out. Kept on the device. */
export interface Tune {
	/** Only titles that are out (or airing). */
	outOnly: boolean;
	/** Include the other mode's version of titles you loved. */
	crossMode: boolean;
	/** Genres to leave out. */
	hiddenGenres: string[];
}

export const DEFAULT_TUNE: Tune = { outOnly: false, crossMode: true, hiddenGenres: [] };

/** The picks Tune keeps. */
export function tunePicks(picks: Pick[], tune: Tune): Pick[] {
	const hidden = new Set(tune.hiddenGenres);
	return picks.filter(
		(p) =>
			!(tune.outOnly && p.title.status === 'Not yet released') &&
			!(!tune.crossMode && p.kind === 'adaptation') &&
			!p.title.genres.some((g) => hidden.has(g))
	);
}

/** Every genre among the picks, most common first: what Tune can leave out. */
export function pickGenres(picks: Pick[]): string[] {
	const counts = new Map<string, number>();
	for (const p of picks) for (const g of p.title.genres) counts.set(g, (counts.get(g) ?? 0) + 1);
	return [...counts.entries()]
		.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
		.map(([g]) => g);
}
