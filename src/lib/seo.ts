// What search engines and link previews (Discord, Reddit, X, iMessage…) see.
// The root layout writes the tags from here, keyed by route id, so a page
// needs no head tags of its own beyond its <title>. A server-rendered page
// can return its own `meta` from its load (a title page: the show's name,
// synopsis and art), which wins over its route's.

import { stripHtml } from '#lib/anilist/humanize.ts';
import type {
	CharacterPerson,
	DetailMedia,
	StaffPerson,
	StudioPage,
	UserAccount
} from '#lib/anilist/types.ts';
import { parseDescription } from '#lib/page-data/markdown.ts';
import { bioText, createCharacterContent, createStaffContent } from '#lib/page-data/person.ts';
import { createStudioContent } from '#lib/page-data/studio.ts';

/** The site's public origin; share cards and the sitemap need absolute URLs. */
export const SITE_URL = 'https://miruyo.vercel.app';

export const SITE_NAME = 'miruyo';

export interface ShareImage {
	url: string;
	width?: number;
	height?: number;
	alt: string;
}

/** The share card: static/og.png. */
const OG_IMAGE: ShareImage = { url: `${SITE_URL}/og.png`, width: 1200, height: 630, alt: 'miruyo' };

/** A page's own tags, returned from its server load as `meta`. */
export interface PageMeta {
	/** The share card's headline (without the site name). */
	title?: string;
	/**
	 * The search result's headline: the page's <title>, without the site name,
	 * when it should say more than the share card ("Frieren Episode 12 Release
	 * Date & Countdown", not just "Frieren"). The page writes it.
	 */
	headline?: string;
	description?: string;
	image?: ShareImage;
	noindex?: boolean;
	/** The canonical path, when its query string matters (/seasonal?season=…). */
	canonical?: string;
	/** schema.org structured data, written as JSON-LD. */
	jsonLd?: Record<string, unknown>;
}

const DEFAULT_DESCRIPTION =
	"A fast front end for your AniList anime and manga list: one-tap progress, what's airing next, and what's trending this season.";

type RouteMeta = {
	/** The share card's headline; the site name when left out. */
	title?: string;
	description?: string;
	/** Listed in sitemap.xml. */
	sitemap?: boolean;
	/** Personal or in-between pages: kept out of search results. */
	noindex?: boolean;
};

const ROUTES: Record<string, RouteMeta> = {
	'/': { sitemap: true },
	'/seasonal': {
		title: 'Seasonal anime chart',
		description:
			"Every anime airing this season, with what's trending, what's new and when each one airs.",
		sitemap: true
	},
	'/schedule': {
		title: 'Anime airing schedule',
		description:
			'The week of anime episodes, day by day, with a countdown to each one in your time zone.',
		sitemap: true
	},
	'/browse': {
		title: 'Browse anime and manga',
		description: 'Browse anime and manga by genre, format, year and season, sorted your way.',
		sitemap: true
	},
	'/search': { title: 'Search', description: 'Search every anime and manga on AniList.' },
	'/title/[id]': {},
	'/staff/[id]': {},
	'/character/[id]': {},
	'/studio/[id]': {},
	// someone's own pages: shared as links, kept out of search results
	'/user/[name]': { noindex: true },
	'/user/[name]/animelist': { noindex: true },
	'/user/[name]/mangalist': { noindex: true },
	'/user/[name]/favourites': { noindex: true },
	'/user/[name]/stats': { noindex: true },
	'/support': { title: 'Support', sitemap: true },
	'/privacy': { title: 'Privacy Policy', sitemap: true },
	'/terms': { title: 'Terms of Use', sitemap: true },
	'/cookies': { title: 'Cookie Policy', sitemap: true },
	'/list': { noindex: true },
	'/for-you': { noindex: true },
	'/profile': { noindex: true },
	'/stats': { noindex: true },
	'/settings': { noindex: true },
	'/welcome': { noindex: true },
	'/login': { noindex: true },
	'/api/callback': { noindex: true }
};

export function routeMeta(routeId: string | null, own?: PageMeta | null) {
	const meta = { ...((routeId && ROUTES[routeId]) || {}), ...own };
	return {
		title: meta.title ? `${meta.title} · ${SITE_NAME}` : SITE_NAME,
		description: meta.description ?? DEFAULT_DESCRIPTION,
		image: own?.image ?? OG_IMAGE,
		// unknown routes (the error page) stay out of the index too
		noindex: meta.noindex ?? !(routeId && routeId in ROUTES),
		canonical: own?.canonical,
		jsonLd: own?.jsonLd
	};
}

/** A description's first ~160 characters, cut at a word: what search results show. */
export function summarize(text: string, max = 160): string {
	const flat = text.replace(/\s+/g, ' ').trim();
	if (flat.length <= max) return flat;
	const cut = flat.slice(0, max - 1);
	return `${cut.slice(0, cut.lastIndexOf(' ')).replace(/[\s,;:.]+$/, '')}…`;
}

/** What a search result calls each format: "TV Anime", "Light Novel"… */
const FORMAT_NOUNS: Record<string, string> = {
	TV: 'TV Anime',
	TV_SHORT: 'TV Anime',
	MOVIE: 'Anime Movie',
	SPECIAL: 'Anime Special',
	OVA: 'OVA',
	ONA: 'ONA',
	MUSIC: 'Music Video',
	MANGA: 'Manga',
	NOVEL: 'Light Novel',
	ONE_SHOT: 'One-shot Manga'
};

/**
 * A title's search headline, by what people search for it: the next episode
 * while it airs, the release date before it starts, and otherwise its year
 * and kind, which tells it apart from its remakes and adaptations.
 */
function titleHeadline(name: string, media: DetailMedia): string {
	const next = media.type === 'ANIME' ? media.nextAiringEpisode : null;
	if (next) return `${name} Episode ${next.episode} Release Date & Countdown`;
	if (media.status === 'NOT_YET_RELEASED') return `${name}: Release Date & Details`;
	const noun =
		(media.format && FORMAT_NOUNS[media.format]) ?? (media.type === 'MANGA' ? 'Manga' : 'Anime');
	const year = media.startDate.year ?? media.seasonYear;
	return `${name} (${year ? `${year} ` : ''}${noun})`;
}

/** A title page's tags, from its signed-out (English-first) details. */
export function titleMeta(media: DetailMedia): PageMeta {
	const name =
		media.title.english ??
		media.title.romaji ??
		media.title.native ??
		media.title.userPreferred ??
		`#${media.id}`;
	const kind = media.type === 'ANIME' ? 'anime' : 'manga';
	const synopsis = media.description ? stripHtml(media.description) : '';
	const next = media.type === 'ANIME' ? media.nextAiringEpisode : null;
	// an airing show's searchers want the next episode: say it comes first
	const lead = next
		? `Countdown to episode ${next.episode} in your time zone, with the airing schedule, studio and cast.`
		: '';
	const description = synopsis
		? summarize(lead ? `${lead} ${synopsis}` : synopsis)
		: lead || `${name}: details, airing and where it sits on your AniList ${kind} list.`;
	const cover = media.coverImage.extraLarge ?? media.coverImage.large;
	// the banner is wide, like a share card; the cover is the fallback
	const image = media.bannerImage ?? cover;
	const altNames = [media.title.romaji, media.title.native, ...media.synonyms].filter(
		(n): n is string => !!n && n !== name
	);
	const date = media.startDate;
	return {
		title: name,
		headline: titleHeadline(name, media),
		description,
		image: image ? { url: image, alt: name } : undefined,
		noindex: media.isAdult,
		jsonLd: {
			'@context': 'https://schema.org',
			'@type': media.type === 'MANGA' ? 'Book' : media.format === 'MOVIE' ? 'Movie' : 'TVSeries',
			name,
			...(altNames.length > 0 && { alternateName: [...new Set(altNames)] }),
			...(!!synopsis && { description: summarize(synopsis, 500) }),
			...(!!cover && { image: cover }),
			...(media.genres.length > 0 && { genre: media.genres }),
			...(!!date.year && {
				datePublished: [date.year, date.month, date.day]
					.filter((n) => n != null)
					.map((n, i) => (i ? String(n).padStart(2, '0') : String(n)))
					.join('-')
			}),
			...(media.type === 'ANIME' && !!media.episodes && { numberOfEpisodes: media.episodes }),
			url: `${SITE_URL}/title/${media.id}`,
			sameAs: `https://anilist.co/${kind}/${media.id}`
		}
	};
}

/** A staff page's tags, from its signed-out details. */
export function staffMeta(staff: StaffPerson): PageMeta {
	const content = createStaffContent(staff, { titles: 'english' });
	const occupation = staff.primaryOccupations?.join(', ');
	const bio = bioText(content.bio);
	const roles = content.voiceRoles.length ? 'voice roles' : 'credits';
	return {
		title: content.name,
		description: bio
			? summarize(bio)
			: `${content.name}${occupation ? `, ${occupation}` : ''}: ${roles} and more on miruyo.`,
		image: content.image ? { url: content.image, alt: content.name } : undefined,
		jsonLd: {
			'@context': 'https://schema.org',
			'@type': 'Person',
			name: content.name,
			...(content.native && { alternateName: [content.native, ...content.altNames] }),
			...(!!bio && { description: summarize(bio, 500) }),
			...(!!content.image && { image: content.image }),
			...(!!occupation && { jobTitle: occupation }),
			url: `${SITE_URL}/staff/${staff.id}`,
			sameAs: `https://anilist.co/staff/${staff.id}`
		}
	};
}

/** A studio page's tags: what it is and its best-known titles. */
export function studioMeta(studio: StudioPage): PageMeta {
	const content = createStudioContent(studio, { titles: 'english' });
	const known = content.titles
		.slice(0, 3)
		.map((t) => t.media.title)
		.join(', ');
	return {
		title: content.name,
		description: `${content.name}, ${content.kind.toLowerCase()}${known ? `: ${known} and more` : ''}. Its titles on miruyo.`,
		jsonLd: {
			'@context': 'https://schema.org',
			'@type': 'Organization',
			name: content.name,
			url: `${SITE_URL}/studio/${studio.id}`,
			sameAs: `https://anilist.co/studio/${studio.id}`
		}
	};
}

/** A character page's tags. Their bio's spoilers are left out. */
export function characterMeta(character: CharacterPerson): PageMeta {
	const content = createCharacterContent(character, { titles: 'english' });
	const bio = bioText(content.bio);
	const from = content.appearances[0]?.media.title;
	return {
		title: content.name,
		description: bio
			? summarize(bio)
			: `${content.name}${from ? `, from ${from}` : ''}: the titles they're in and who voices them.`,
		image: content.image ? { url: content.image, alt: content.name } : undefined
	};
}

/** A user page's share card: their name, bio and avatar. Never indexed. */
export function userMeta(account: UserAccount): PageMeta {
	const bio = bioText(parseDescription(account.about).paragraphs);
	return {
		title: account.name,
		description: bio
			? summarize(bio)
			: `${account.name}’s anime and manga: favourites, stats and their list.`,
		image: account.avatar?.large ? { url: account.avatar.large, alt: account.name } : undefined,
		noindex: true
	};
}

/** The paths sitemap.xml lists. */
export const SITEMAP_PATHS = Object.entries(ROUTES)
	.filter(([, meta]) => meta.sitemap)
	.map(([path]) => path);
