import {
	adaptMedia,
	coverBackground,
	coverColor,
	externalUrl,
	type TitlePreference
} from '#lib/anilist/adapt.ts';
import { humanizeFormat, humanizeSeason, humanizeStatus } from '#lib/anilist/humanize.ts';
import type { AniListDate, AniListSavedEntry, DetailMedia, MediaType } from '#lib/anilist/types.ts';
import { dressTitle } from '#lib/catalog/dress.ts';
import type { Title } from '#lib/catalog/types.ts';
import { studioHref } from './studio-link.ts';

export interface InfoRow {
	label: string;
	value: string;
	/** Where the value leads in miruyo (the studio's page). */
	href?: string;
}

export interface Person {
	id: number;
	name: string;
	/** Character role (Main / Supporting) or staff role (Story & Art). */
	role: string;
	image: string | null;
}

export interface CharacterCard extends Person {
	/** Japanese voice actor, for anime. */
	voice: Person | null;
}

export interface RelationCard {
	id: number;
	relation: string;
	/** Label colour by kind: source, sequel/prequel, adaptation, other. */
	color: string;
	title: string;
	meta: string;
	cover: string;
}

export interface TagChip {
	name: string;
	/** How well it fits, 0–100. */
	rank: number;
	/** Gives away the story: hidden until asked for. */
	spoiler: boolean;
	description: string | null;
}

export interface LinkChip {
	id: number;
	site: string;
	url: string;
	/** "Thai", "Muse Asia" — what tells two links to one site apart. */
	detail: string;
	/** The site's logo (https), or null for the generic icon. */
	icon: string | null;
	/** The logo's backdrop: the site's colour as plain hex, or null. */
	color: string | null;
}

export interface DetailContent {
	title: Title;
	/** CSS background for the banner; null → the page blurs the cover instead. */
	banner: string | null;
	/** "TV · Fall 2026 · Madhouse" / "Manga · 2023 – present". */
	overline: string;
	/** Other names for the title (English / native), not repeating the main one. */
	altTitles: string;
	/** Further names (translations, abbreviations), not repeating any of the above. */
	synonyms: string[];
	/** Best fit first; 18+ tags only when the account shows adult content. */
	tags: TagChip[];
	/** Where to watch (anime) or read (manga) it. */
	watch: LinkChip[];
	/** Official site and socials. */
	links: LinkChip[];
	rank: { value: string; label: string } | null;
	members: string;
	info: InfoRow[];
	characters: CharacterCard[];
	/** Manga: the people credited with story / art. */
	authors: Person[];
	relations: RelationCard[];
	recommendations: Title[];
	trailer: { url: string; thumbnail: string | null } | null;
	/** Unix seconds and episode number of the next airing, if scheduled. */
	nextAiring: { episode: number; at: number } | null;
	entry: AniListSavedEntry | null;
	isFavourite: boolean;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** 912345 → "912k", 1234567 → "1.2M". */
export function formatCompact(n: number | null): string {
	if (n == null) return '—';
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
	if (n >= 1000) return `${Math.round(n / 1000)}k`;
	return String(n);
}

/** SIDE_STORY → "Side story", LIGHT_NOVEL → "Light novel". */
export function humanizeEnum(value: string | null): string {
	if (!value) return '';
	const words = value.toLowerCase().split('_');
	return [words[0][0].toUpperCase() + words[0].slice(1), ...words.slice(1)].join(' ');
}

function monthYear(date: AniListDate): string {
	if (!date.year) return '';
	return date.month ? `${MONTHS[date.month - 1]} ${date.year}` : String(date.year);
}

/** "Fri 23:00" in the viewer's timezone (or `timeZone`, for tests). */
export function formatAiring(unixSeconds: number, timeZone?: string): string {
	return new Intl.DateTimeFormat('en-GB', {
		weekday: 'short',
		hour: '2-digit',
		minute: '2-digit',
		hour12: false,
		timeZone
	}).format(new Date(unixSeconds * 1000));
}

/** "Fri, Oct 9 · 23:00" — the countdown card's full local date and time. */
export function formatAiringLong(unixSeconds: number, timeZone?: string): string {
	const date = new Date(unixSeconds * 1000);
	const day = new Intl.DateTimeFormat('en-US', {
		weekday: 'short',
		month: 'short',
		day: 'numeric',
		timeZone
	}).format(date);
	const time = new Intl.DateTimeFormat('en-GB', {
		hour: '2-digit',
		minute: '2-digit',
		hour12: false,
		timeZone
	}).format(date);
	return `${day} · ${time}`;
}

const RELATION_ORDER = [
	'SOURCE',
	'PREQUEL',
	'SEQUEL',
	'PARENT',
	'SIDE_STORY',
	'ADAPTATION',
	'ALTERNATIVE',
	'SPIN_OFF',
	'SUMMARY',
	'COMPILATION',
	'CONTAINS',
	'OTHER',
	'CHARACTER'
];

/**
 * What a relation is, for ordering and its label. AniList often files an
 * anime's original novel or manga as ADAPTATION rather than SOURCE; from an
 * anime, an adaptation that isn't itself anime is the source.
 */
export function relationKind(
	relationType: string,
	mediaType: MediaType,
	nodeType: MediaType
): string {
	return relationType === 'ADAPTATION' && mediaType === 'ANIME' && nodeType !== 'ANIME'
		? 'SOURCE'
		: relationType;
}

/** Sortable start date; undated relations go last within their kind. */
function startKey(d: AniListDate | null | undefined): number {
	return d?.year ? d.year * 10000 + (d.month ?? 12) * 100 + (d.day ?? 31) : 99999999;
}

function relationColor(type: string): string {
	if (type === 'SOURCE') return '#B9A9FF';
	if (type === 'PREQUEL' || type === 'SEQUEL') return '#F07A63';
	if (type === 'ADAPTATION') return '#FF8A78';
	return '#B3A996';
}

function trailerUrl(trailer: DetailMedia['trailer']): DetailContent['trailer'] {
	if (!trailer?.id) return null;
	if (trailer.site === 'youtube') {
		return {
			url: `https://www.youtube.com/watch?v=${encodeURIComponent(trailer.id)}`,
			thumbnail: trailer.thumbnail
		};
	}
	if (trailer.site === 'dailymotion') {
		return {
			url: `https://www.dailymotion.com/video/${encodeURIComponent(trailer.id)}`,
			thumbnail: trailer.thumbnail
		};
	}
	return null;
}

/** A title's links, the viewer's likeliest language first (none given, then English). */
function linkChips(links: DetailMedia['externalLinks']): LinkChip[] {
	const order = (language: string | null) => (!language ? 0 : language === 'English' ? 1 : 2);
	return links
		.filter((l) => !l.isDisabled)
		.sort((a, b) => order(a.language) - order(b.language))
		.flatMap((l): LinkChip[] => {
			const url = externalUrl(l.url);
			if (!url) return [];
			const icon = externalUrl(l.icon);
			return [
				{
					id: l.id,
					site: l.site,
					url,
					detail: [l.language && l.language !== 'English' ? l.language : '', l.notes ?? '']
						.filter(Boolean)
						.join(' · '),
					icon: icon?.startsWith('https:') ? icon : null,
					color: l.color && /^#[0-9a-f]{6}$/i.test(l.color) ? l.color : null
				}
			];
		});
}

/** Story / art credits — the people a manga reader means by "author". */
function authorsOf(media: DetailMedia): Person[] {
	return media.staff.edges
		.filter((e) => /story|art|original creator/i.test(e.role) && !/assistant/i.test(e.role))
		.map((e) => ({
			id: e.node.id,
			name: e.node.name.full,
			role: e.role,
			image: e.node.image?.medium ?? null
		}));
}

/**
 * Builds the title page from DETAIL_QUERY. Titles follow the viewer's
 * AniList preference when signed in, English otherwise; 18+ tags show only
 * when `adult` (the account's adult-content setting) is on.
 */
export function createDetailContent(
	media: DetailMedia,
	{
		titles = 'userPreferred',
		timeZone,
		adult = false
	}: { titles?: TitlePreference; timeZone?: string; adult?: boolean } = {}
): DetailContent {
	const isAnime = media.type === 'ANIME';
	const title = adaptMedia(media, media.mediaListEntry ?? undefined, { titles });
	const authors = authorsOf(media);
	const mainStudio = media.studios.nodes[0];
	const studio = mainStudio?.name;

	// names that differ only in case ("ONE PIECE" / "One Piece") count as one
	const known = new Set([title.title.toLowerCase()]);
	const names: string[] = [];
	for (const n of [media.title.english, media.title.romaji, media.title.native]) {
		if (!n || known.has(n.toLowerCase())) continue;
		known.add(n.toLowerCase());
		names.push(n);
	}
	const synonyms = [...new Set(media.synonyms.map((n) => n.trim()))].filter(
		(n) => n && !known.has(n.toLowerCase())
	);
	const links = linkChips(media.externalLinks);
	const linkType = new Map(media.externalLinks.map((l) => [l.id, l.type]));

	const started = monthYear(media.startDate);
	const ended = monthYear(media.endDate);
	const span =
		media.status === 'RELEASING' && media.startDate.year
			? `${media.startDate.year} – present`
			: media.startDate.year && media.endDate.year && media.endDate.year !== media.startDate.year
				? `${media.startDate.year} – ${media.endDate.year}`
				: media.startDate.year
					? String(media.startDate.year)
					: '';

	const overline = isAnime
		? [title.format, title.season ?? span, studio].filter(Boolean).join(' · ')
		: [title.format, span].filter(Boolean).join(' · ');

	const rated = media.rankings.find((r) => r.type === 'RATED' && r.allTime);
	const popular = media.rankings.find((r) => r.type === 'POPULAR' && r.allTime);
	const best = rated ?? popular;

	const next = media.nextAiringEpisode;
	const info: InfoRow[] = isAnime
		? [
				{
					label: 'Format',
					value: [title.format, media.duration ? `${media.duration} min` : '']
						.filter(Boolean)
						.join(' · ')
				},
				{ label: 'Episodes', value: media.episodes ? String(media.episodes) : 'Unknown' },
				{ label: 'Status', value: humanizeStatus(media.status) },
				...(media.season && media.seasonYear
					? [{ label: 'Season', value: `${humanizeSeason(media.season)} ${media.seasonYear}` }]
					: []),
				...(mainStudio
					? [{ label: 'Studio', value: mainStudio.name, href: studioHref(mainStudio.id) }]
					: []),
				...(media.source ? [{ label: 'Source', value: humanizeEnum(media.source) }] : []),
				...(next
					? [
							{
								label: 'Next episode',
								value: `EP ${next.episode} · ${formatAiring(next.airingAt, timeZone)}`
							}
						]
					: [])
			]
		: [
				{ label: 'Format', value: humanizeFormat(media.format) },
				{
					label: 'Chapters',
					value: media.chapters
						? String(media.chapters)
						: media.status === 'RELEASING'
							? 'Ongoing'
							: 'Unknown'
				},
				...(media.volumes ? [{ label: 'Volumes', value: String(media.volumes) }] : []),
				{ label: 'Status', value: humanizeStatus(media.status) },
				...(authors.length
					? [{ label: 'Story & Art', value: [...new Set(authors.map((a) => a.name))].join(', ') }]
					: []),
				...(started ? [{ label: 'Started', value: started }] : []),
				...(ended && media.status === 'FINISHED' ? [{ label: 'Finished', value: ended }] : [])
			];

	// source first, then prequels, sequels and the rest; oldest first within each
	const kindOf = (edge: (typeof media.relations.edges)[number]) =>
		relationKind(edge.relationType, media.type, edge.node.type);
	const relations = [...media.relations.edges]
		.sort(
			(a, b) =>
				(RELATION_ORDER.indexOf(kindOf(a)) + 1 || 99) -
					(RELATION_ORDER.indexOf(kindOf(b)) + 1 || 99) ||
				startKey(a.node.startDate) - startKey(b.node.startDate)
		)
		.map((edge): RelationCard => {
			const n = edge.node;
			const kind = kindOf(edge);
			const name =
				(titles === 'english'
					? (n.title.english ?? n.title.romaji)
					: (n.title.userPreferred ?? n.title.romaji)) ?? 'Untitled';
			const length =
				n.type === 'ANIME'
					? n.episodes
						? `${n.episodes} eps`
						: ''
					: n.chapters
						? `${n.chapters} ch`
						: '';
			const colour = coverColor(n.coverImage.color);
			return {
				id: n.id,
				relation: humanizeEnum(kind),
				color: relationColor(kind),
				title: name,
				meta: [humanizeFormat(n.format), length, n.seasonYear ? String(n.seasonYear) : '']
					.filter((x) => x && x !== 'Unknown')
					.join(' · '),
				cover: n.coverImage.large
					? coverBackground(n.coverImage.large)
					: dressTitle({
							id: n.id,
							title: name,
							type: n.type,
							format: '',
							score: 0,
							color: colour,
							genres: [],
							status: ''
						}).cover
			};
		});

	return {
		title,
		banner: title.banner ?? null,
		overline,
		altTitles: names.join(' · '),
		synonyms,
		tags: media.tags
			.filter((t) => adult || !t.isAdult)
			.sort((a, b) => b.rank - a.rank)
			.map((t) => ({
				name: t.name,
				rank: t.rank,
				spoiler: t.isMediaSpoiler || t.isGeneralSpoiler,
				description: t.description
			})),
		watch: links.filter((l) => linkType.get(l.id) === 'STREAMING'),
		links: links.filter((l) => linkType.get(l.id) !== 'STREAMING'),
		rank: best
			? {
					value: `#${best.rank}`,
					label: best.type === 'RATED' ? 'Highest rated all time' : 'Most popular all time'
				}
			: null,
		members: formatCompact(media.popularity),
		info,
		characters: media.characters.edges.map((e) => ({
			id: e.node.id,
			name: e.node.name.full,
			role: humanizeEnum(e.role),
			image: e.node.image?.medium ?? null,
			voice: e.voiceActors[0]
				? {
						id: e.voiceActors[0].id,
						name: e.voiceActors[0].name.full,
						role: 'Japanese',
						image: e.voiceActors[0].image?.medium ?? null
					}
				: null
		})),
		authors,
		relations,
		recommendations: media.recommendations.nodes
			.map((n) => n.mediaRecommendation)
			.filter((m): m is NonNullable<typeof m> => !!m)
			.map((m) => adaptMedia(m, undefined, { titles })),
		trailer: trailerUrl(media.trailer),
		nextAiring: next ? { episode: next.episode, at: next.airingAt } : null,
		entry: media.mediaListEntry,
		isFavourite: media.isFavourite
	};
}
