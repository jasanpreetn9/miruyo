import type { MediaListStatus, TitleRanking, TitleStatsResponse } from '#lib/anilist/types.ts';
import { LIST_STATUSES, statusLabel } from '#lib/catalog/status.ts';
import { formatCompact } from './detail.ts';

// A title's Stats tab (TitleStats.svelte): its rankings, how many people
// have it on each list, and how they score it. All from AniList's own
// counts across every user (TITLE_STATS_QUERY).

export interface RankingRow {
	key: number;
	rank: number;
	/** "Highest rated" / "Most popular". */
	label: string;
	/** "All time", "2023", "Fall 2023". */
	when: string;
	/** "TV": the ranking is among titles of this format. */
	format: string;
	/** The same list in Browse, when Browse can show it. */
	href: string | null;
}

export interface StatusRow {
	status: MediaListStatus;
	label: string;
	count: number;
	/** "1.2k". */
	shown: string;
	/** Of everyone with it on a list, 0–100. */
	percent: number;
}

export interface ScoreBar {
	/** 1–10. */
	score: number;
	count: number;
	/** Of the tallest bar, 0–100. */
	height: number;
}

export interface TitleStats {
	rankings: RankingRow[];
	statuses: StatusRow[];
	/** Everyone with it on a list. */
	members: string;
	scores: ScoreBar[];
	/** "211k". */
	scored: string;
	/** "9.1", or null with no average yet. */
	average: string | null;
	favourites: string | null;
}

const SEASONS: Record<string, string> = {
	WINTER: 'Winter',
	SPRING: 'Spring',
	SUMMER: 'Summer',
	FALL: 'Fall'
};
const FORMATS: Record<string, string> = {
	TV: 'TV',
	TV_SHORT: 'TV Short',
	MOVIE: 'Movie',
	SPECIAL: 'Special',
	OVA: 'OVA',
	ONA: 'ONA',
	MUSIC: 'Music',
	MANGA: 'Manga',
	NOVEL: 'Light novel',
	ONE_SHOT: 'One-shot'
};

/**
 * Browse sorted the same way, narrowed to the same format and (anime only:
 * Browse has no year for manga) the same season and year.
 */
function rankingHref(r: TitleRanking, isAnime: boolean): string | null {
	if (!r.allTime && !isAnime) return null;
	const p = new URLSearchParams();
	if (r.type === 'RATED') p.set('sort', 'score');
	if (r.format) p.append('format', r.format);
	if (!r.allTime) {
		if (r.season) p.set('season', r.season);
		if (r.year) p.set('year', String(r.year));
	}
	const qs = p.toString();
	return qs ? `/browse?${qs}` : '/browse';
}

export function buildTitleStats(
	media: TitleStatsResponse['Media'],
	{ isAnime }: { isAnime: boolean }
): TitleStats {
	const rankings = (media.rankings ?? [])
		.slice()
		// all time first, then the year, then the season
		.sort(
			(a, b) =>
				Number(b.allTime) - Number(a.allTime) ||
				Number(!!a.season) - Number(!!b.season) ||
				(a.type === 'RATED' ? 0 : 1) - (b.type === 'RATED' ? 0 : 1)
		)
		.map((r) => ({
			key: r.id,
			rank: r.rank,
			label: r.type === 'RATED' ? 'Highest rated' : 'Most popular',
			when: r.allTime
				? 'All time'
				: [r.season ? SEASONS[r.season] : '', r.year ?? ''].filter(Boolean).join(' '),
			format: FORMATS[r.format] ?? r.format,
			href: rankingHref(r, isAnime)
		}));

	const byStatus = new Map(
		(media.stats?.statusDistribution ?? []).map((s) => [s.status, s.amount] as const)
	);
	const total = [...byStatus.values()].reduce((a, n) => a + n, 0);
	const statuses = LIST_STATUSES.filter((s) => byStatus.get(s)).map((status) => {
		const count = byStatus.get(status)!;
		return {
			status,
			label: statusLabel(status, isAnime),
			count,
			shown: formatCompact(count),
			percent: total ? Math.round((count / total) * 1000) / 10 : 0
		};
	});

	const byScore = new Map(
		(media.stats?.scoreDistribution ?? []).map((s) => [s.score, s.amount] as const)
	);
	const counts = Array.from({ length: 10 }, (_, i) => byScore.get((i + 1) * 10) ?? 0);
	const tallest = Math.max(0, ...counts);
	const scores = counts.map((count, i) => ({
		score: i + 1,
		count,
		height: tallest ? Math.max(count ? 2 : 0, Math.round((count / tallest) * 100)) : 0
	}));

	return {
		rankings,
		statuses,
		members: formatCompact(total),
		scores,
		scored: formatCompact(counts.reduce((a, n) => a + n, 0)),
		average: media.averageScore ? (media.averageScore / 10).toFixed(1) : null,
		favourites: media.favourites ? formatCompact(media.favourites) : null
	};
}
