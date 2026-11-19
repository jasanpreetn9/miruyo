import { dressTitle, type RawTitle } from '#lib/catalog/dress.ts';
import type { MyProgress, Title } from '#lib/catalog/types.ts';
import {
	formatTimeUntil,
	humanizeFormat,
	humanizeSeason,
	humanizeStatus,
	stripHtml,
	toListStatus
} from './humanize.ts';
import type { AniListMedia, AniListMediaTitle } from './types.ts';

/** The viewer's list entry for a title: a full list entry, or the one a feed query attaches. */
type ListEntryLike = { status: string; progress: number };

const FALLBACK_COLOR = '#30363d';

/**
 * AniList's dominant cover colour, or the fallback when it isn't a plain hex
 * colour: it's spliced into inline CSS, so anything else could inject rules.
 */
export function coverColor(color: string | null | undefined): string {
	return color && /^#[0-9a-f]{6}$/i.test(color) ? color : FALLBACK_COLOR;
}

/**
 * An AniList page link from the API (siteUrl), or `fallback` when it isn't an
 * https anilist.co URL, so an unexpected value (a javascript: URL) never
 * becomes a link.
 */
export function anilistUrl(url: string | null | undefined, fallback: string): string;
export function anilistUrl(url: string | null | undefined, fallback?: null): string | null;
export function anilistUrl(url: string | null | undefined, fallback: string | null = null) {
	if (!url) return fallback;
	try {
		const { protocol, hostname } = new URL(url);
		return protocol === 'https:' && hostname === 'anilist.co' ? url : fallback;
	} catch {
		return fallback;
	}
}

/**
 * A link to another site from the API (a title's external links), or null
 * when it isn't http(s), so an unexpected value never becomes a link.
 */
export function externalUrl(url: string | null | undefined): string | null {
	if (!url) return null;
	try {
		const { protocol } = new URL(url);
		return protocol === 'https:' || protocol === 'http:' ? url : null;
	} catch {
		return null;
	}
}

/** A CSS `url()` for an image URL. */
export function cssUrl(url: string): string {
	// encode quotes/parens so the URL can't break out of the CSS url()
	const safe = url.replace(/['"()\\]/g, (c) => '%' + c.charCodeAt(0).toString(16));
	return `url('${safe}')`;
}

/** A CSS `background` value for an image URL, covering its box. */
export function coverBackground(url: string): string {
	return `center / cover no-repeat ${cssUrl(url)}`;
}

/**
 * Which title to show. 'userPreferred' is AniList's own pick for the signed-in
 * viewer (their account's title language setting), so it's only meaningful on
 * authenticated requests; signed-out visitors get 'english'.
 */
export type TitlePreference = 'userPreferred' | 'english';

export interface AdaptOptions {
	titles?: TitlePreference;
}

export function pickTitle(title: AniListMediaTitle, preference: TitlePreference): string {
	const order =
		preference === 'english'
			? [title.english, title.romaji, title.userPreferred, title.native]
			: [title.userPreferred, title.romaji, title.english, title.native];
	return order.find((t) => !!t) ?? 'Untitled';
}

/**
 * Converts a real AniList media object (+ the viewer's list entry for it, if
 * any — passed in, or attached by the query as `mediaListEntry`) into the same `Title` shape the UI already knows how to render —
 * reuses dressTitle() for accent/glow/tint (derived from AniList's own
 * dominant cover color) and only swaps in the real cover image afterward.
 */
export function adaptMedia(
	media: AniListMedia,
	listEntry?: ListEntryLike,
	{ titles = 'userPreferred' }: AdaptOptions = {}
): Title {
	const isAnime = media.type === 'ANIME';
	const entry = listEntry ?? media.mediaListEntry ?? undefined;

	const raw: RawTitle = {
		id: media.id,
		title: pickTitle(media.title, titles),
		en: media.title.english ?? undefined,
		type: media.type,
		format: humanizeFormat(media.format),
		eps: isAnime ? (media.episodes ?? null) : undefined,
		duration: isAnime ? (media.duration ?? undefined) : undefined,
		ch: !isAnime ? (media.chapters ?? null) : undefined,
		vol: !isAnime ? (media.volumes ?? null) : undefined,
		score: media.averageScore != null ? media.averageScore / 10 : 0,
		color: coverColor(media.coverImage.color),
		genres: media.genres,
		// AniList's Media.studios is anime-centric; manga rarely has entries
		// here (and we don't query staff for an author name), so "by" text
		// is often blank for manga — a known gap, not a bug.
		studio: media.studios.nodes[0]?.name,
		author: undefined,
		season:
			media.season && media.seasonYear
				? `${humanizeSeason(media.season)} ${media.seasonYear}`
				: undefined,
		status: humanizeStatus(media.status),
		next: media.nextAiringEpisode
			? {
					ep: media.nextAiringEpisode.episode,
					in: formatTimeUntil(media.nextAiringEpisode.timeUntilAiring),
					at: media.nextAiringEpisode.airingAt
				}
			: undefined,
		me: entry ? ({ s: toListStatus(entry.status), p: entry.progress } as MyProgress) : undefined,
		adult: media.isAdult,
		synopsis: media.description ? stripHtml(media.description) : undefined,
		banner: media.bannerImage ? coverBackground(media.bannerImage) : undefined
	};

	const title = dressTitle(raw);

	const image = media.coverImage.extraLarge ?? media.coverImage.large;
	if (image) {
		title.cover = coverBackground(image);
		title.coverUrl = image;
		if (media.coverImage.large) {
			title.thumb = coverBackground(media.coverImage.large);
			title.thumbUrl = media.coverImage.large;
			// AniList's medium cover is 100px wide: plenty for a row's thumbnail
			// below a 3x screen, at a third of the bytes
			if (media.coverImage.medium) title.thumbSmallUrl = media.coverImage.medium;
		}
	} else {
		title.coverMissing = true;
	}

	return title;
}
