import { anilistUrl, coverColor, pickTitle, type TitlePreference } from '#lib/anilist/adapt.ts';
import { humanizeFormat } from '#lib/anilist/humanize.ts';
import type {
	AniListDate,
	CharacterPerson,
	PersonMedia,
	PersonName,
	StaffPerson
} from '#lib/anilist/types.ts';
import { formatCompact, humanizeEnum } from './detail.ts';
import { parseDescription, type Fact, type Paragraph } from './markdown.ts';

// The staff and character pages (/staff/[id], /character/[id]): who someone
// is, then the titles they're in. Titles follow the viewer's AniList
// preference when signed in, English otherwise; 18+ titles only show when the
// account allows them.

export interface PersonOptions {
	titles?: TitlePreference;
	adult?: boolean;
}

/** A title in someone's roles. */
export interface MediaCard {
	id: number;
	title: string;
	/** "2023 · TV". */
	meta: string;
	cover: string | null;
	/** The frame's colour while the cover loads. */
	color: string;
	isAnime: boolean;
}

export interface PersonLink {
	id: number;
	name: string;
	image: string | null;
}

export interface VoiceRoleCard {
	key: string;
	media: MediaCard;
	character: PersonLink;
	/** "Main" / "Supporting" / "Background". */
	role: string;
}

export interface CreditCard {
	key: string;
	media: MediaCard;
	/** Every role they had on it: "Original Creator · Story & Art". */
	roles: string;
}

export interface VoiceActor extends PersonLink {
	language: string;
	/** "(young)", "(adult)". */
	note: string | null;
}

export interface AppearanceCard {
	key: string;
	media: MediaCard;
	role: string;
	/** Every language's voice actors; the page shows one language at a time. */
	voices: VoiceActor[];
}

export interface PersonHeader {
	name: string;
	native: string | null;
	altNames: string[];
	/** Names that give away the story: hidden until asked for. */
	spoilerNames: string[];
	image: string | null;
	facts: Fact[];
	bio: Paragraph[];
	/** "3.9k". */
	favourites: string;
	isFavourite: boolean;
	anilistHref: string;
}

export interface StaffContent extends PersonHeader {
	voiceRoles: VoiceRoleCard[];
	voiceHasMore: boolean;
	credits: CreditCard[];
	creditsHasMore: boolean;
	/** Voice actors lead with their roles; authors and directors with their credits. */
	voiceFirst: boolean;
}

export interface CharacterContent extends PersonHeader {
	appearances: AppearanceCard[];
	hasMore: boolean;
	/** The languages voicing them, Japanese first, then English, then by how many. */
	languages: string[];
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "Sep 27, 1990", "Sep 27" (no year) or "1990" (no day). */
export function formatDate(date: AniListDate): string {
	const month = date.month ? MONTHS[date.month - 1] : '';
	const day = month && date.day ? `${month} ${date.day}` : month;
	if (day && date.year) return `${day}, ${date.year}`;
	return day || (date.year ? String(date.year) : '');
}

const fact = (label: string, value: string | number | null | undefined): Fact[] =>
	value || value === 0 ? [{ label, value: String(value) }] : [];

/** A title as a role card shows it (also a studio's titles). */
export function mediaCard(m: PersonMedia, titles: TitlePreference): MediaCard {
	const year = m.startDate.year ?? m.seasonYear;
	const format = humanizeFormat(m.format);
	return {
		id: m.id,
		title: pickTitle(m.title, titles),
		meta: [year ? String(year) : '', format === 'Unknown' ? '' : format]
			.filter(Boolean)
			.join(' · '),
		cover: m.coverImage.large,
		color: coverColor(m.coverImage.color),
		isAnime: m.type === 'ANIME'
	};
}

function header(
	person: {
		id: number;
		name: PersonName & { alternativeSpoiler?: string[] | null };
		image: { large: string | null } | null;
		description: string | null;
		favourites: number | null;
		isFavourite: boolean;
		siteUrl: string | null;
	},
	kind: 'staff' | 'character',
	facts: Fact[]
): PersonHeader {
	const name = person.name.userPreferred ?? person.name.full;
	const native = person.name.native && person.name.native !== name ? person.name.native : null;
	const seen = new Set([name, native].filter(Boolean).map((n) => n!.toLowerCase()));
	const unique = (names: (string | null)[] | null | undefined) =>
		(names ?? []).filter((n): n is string => {
			const key = n?.trim().toLowerCase();
			if (!key || seen.has(key)) return false;
			seen.add(key);
			return true;
		});
	const altNames = unique([person.name.full, ...(person.name.alternative ?? [])]);
	const description = parseDescription(person.description);
	return {
		name,
		native,
		altNames,
		spoilerNames: unique(person.name.alternativeSpoiler),
		image: person.image?.large ?? null,
		facts: [...facts, ...description.facts],
		bio: description.paragraphs,
		favourites: formatCompact(person.favourites),
		isFavourite: person.isFavourite,
		anilistHref: anilistUrl(person.siteUrl, `https://anilist.co/${kind}/${person.id}`)
	};
}

/**
 * A bio as plain text for search results and share cards: without its
 * spoilers, or lines that are only links ("Twitter | Official site").
 */
export function bioText(bio: Paragraph[]): string {
	return bio
		.filter((p) => p.some((s) => !s.href && !/^[\s|·•,/-]*$/.test(s.text)))
		.map((p) =>
			p
				.filter((s) => !s.spoiler)
				.map((s) => s.text)
				.join('')
				.trim()
		)
		.filter(Boolean)
		.join(' ');
}

export function createStaffContent(
	staff: StaffPerson,
	{ titles = 'userPreferred', adult = false }: PersonOptions = {}
): StaffContent {
	const alive = !staff.dateOfDeath.year;
	const [start, end] = staff.yearsActive ?? [];
	const facts = [
		...fact('Occupation', staff.primaryOccupations?.join(', ')),
		...fact('Birthday', formatDate(staff.dateOfBirth)),
		...(alive ? fact('Age', staff.age) : fact('Died', formatDate(staff.dateOfDeath))),
		...fact('Gender', staff.gender),
		...fact('Years active', start ? `${start} – ${end ?? (alive ? 'present' : '?')}` : null),
		...fact('Hometown', staff.homeTown),
		...fact('Blood type', staff.bloodType),
		...fact('Language', staff.languageV2)
	];

	const voiceRoles: VoiceRoleCard[] = [];
	const seenRoles = new Set<string>();
	for (const edge of staff.characterMedia.edges) {
		if (edge.node.isAdult && !adult) continue;
		for (const c of edge.characters) {
			const key = `${edge.node.id}-${c?.id}`;
			if (!c || seenRoles.has(key)) continue;
			seenRoles.add(key);
			voiceRoles.push({
				key,
				media: mediaCard(edge.node, titles),
				character: {
					id: c.id,
					name: c.name.userPreferred ?? c.name.full,
					image: c.image?.medium ?? null
				},
				role: humanizeEnum(edge.characterRole)
			});
		}
	}

	// AniList sends one edge per role; a title they had several roles on is one card
	const credits = new Map<number, { media: MediaCard; roles: string[] }>();
	for (const edge of staff.staffMedia.edges) {
		if (edge.node.isAdult && !adult) continue;
		const card = credits.get(edge.node.id) ?? { media: mediaCard(edge.node, titles), roles: [] };
		if (edge.staffRole && !card.roles.includes(edge.staffRole)) card.roles.push(edge.staffRole);
		credits.set(edge.node.id, card);
	}

	return {
		...header(staff, 'staff', facts),
		voiceRoles,
		voiceHasMore: staff.characterMedia.pageInfo.hasNextPage,
		credits: [...credits.values()].map((c) => ({
			key: String(c.media.id),
			media: c.media,
			roles: c.roles.join(' · ')
		})),
		creditsHasMore: staff.staffMedia.pageInfo.hasNextPage,
		voiceFirst:
			staff.characterMedia.edges.length > 0 &&
			(staff.primaryOccupations?.includes('Voice Actor') ||
				staff.characterMedia.edges.length >= staff.staffMedia.edges.length)
	};
}

/** Japanese first (the original), then English, then by how many titles. */
function languageOrder(counts: Map<string, number>): string[] {
	const rank = (l: string) => (l === 'Japanese' ? 0 : l === 'English' ? 1 : 2);
	return [...counts.keys()].sort(
		(a, b) => rank(a) - rank(b) || counts.get(b)! - counts.get(a)! || a.localeCompare(b)
	);
}

export function createCharacterContent(
	character: CharacterPerson,
	{ titles = 'userPreferred', adult = false }: PersonOptions = {}
): CharacterContent {
	const facts = [
		...fact('Gender', character.gender),
		...fact('Age', character.age),
		...fact('Birthday', formatDate(character.dateOfBirth)),
		...fact('Blood type', character.bloodType)
	];

	const counts = new Map<string, number>();
	const seen = new Set<number>();
	const appearances: AppearanceCard[] = [];
	for (const edge of character.media.edges) {
		if ((edge.node.isAdult && !adult) || seen.has(edge.node.id)) continue;
		seen.add(edge.node.id);
		const voices: VoiceActor[] = [];
		for (const r of edge.voiceActorRoles ?? []) {
			const va = r.voiceActor;
			if (!va || voices.some((v) => v.id === va.id)) continue;
			const language = va.languageV2 ?? 'Unknown';
			voices.push({
				id: va.id,
				name: va.name.userPreferred ?? va.name.full,
				image: va.image?.medium ?? null,
				language,
				note: r.roleNotes
			});
		}
		for (const language of new Set(voices.map((v) => v.language))) {
			counts.set(language, (counts.get(language) ?? 0) + 1);
		}
		appearances.push({
			key: String(edge.node.id),
			media: mediaCard(edge.node, titles),
			role: humanizeEnum(edge.characterRole),
			voices
		});
	}

	return {
		...header(character, 'character', facts),
		appearances,
		hasMore: character.media.pageInfo.hasNextPage,
		languages: languageOrder(counts)
	};
}
