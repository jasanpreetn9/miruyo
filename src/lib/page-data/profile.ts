import { adaptMedia, anilistUrl } from '#lib/anilist/adapt.ts';
import type { AniListMedia, FavouritePerson, Profile } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';
import { studioHref } from './studio-link.ts';

/** A favourite character or staff member; they have no page in miruyo, so they link to AniList. */
export interface ProfilePerson {
	id: number;
	name: string;
	image: string | null;
	href: string;
}

export interface ProfileStudio {
	id: number;
	name: string;
	href: string;
}

export interface ProfileView {
	/** "Member since March 2019", or null when AniList doesn't say. */
	memberSince: string | null;
	/** Their page on AniList. */
	anilistHref: string | null;
	anime: Title[];
	manga: Title[];
	/** Why the favourite titles didn't load; the rest of the profile still shows. */
	titlesError: string | null;
	characters: ProfilePerson[];
	staff: ProfilePerson[];
	studios: ProfileStudio[];
}

const MONTHS = [
	'January',
	'February',
	'March',
	'April',
	'May',
	'June',
	'July',
	'August',
	'September',
	'October',
	'November',
	'December'
];

function person(p: FavouritePerson, kind: 'character' | 'staff'): ProfilePerson {
	return {
		id: p.id,
		name: p.name.userPreferred ?? 'Unknown',
		image: p.image?.large ?? p.image?.medium ?? null,
		href: `/${kind}/${p.id}`
	};
}

/** Each id once, first one kept: AniList can list a favourite twice. */
function once<T extends { id: number }>(list: T[]): T[] {
	const seen = new Set<number>();
	return list.filter((x) => {
		if (seen.has(x.id)) return false;
		seen.add(x.id);
		return true;
	});
}

export function buildProfile(
	{ account, anime, manga, titlesError }: Profile,
	{ timeZone, showAdult }: { timeZone?: string; showAdult: boolean }
): ProfileView {
	const fav = account.favourites;
	const media = (list: AniListMedia[] | null) =>
		once(list ?? [])
			.filter((m) => showAdult || !m.isAdult)
			.map((m) => adaptMedia(m));

	let memberSince: string | null = null;
	if (account.createdAt) {
		const parts = new Intl.DateTimeFormat('en-US', {
			year: 'numeric',
			month: 'numeric',
			timeZone
		}).formatToParts(new Date(account.createdAt * 1000));
		const month = Number(parts.find((p) => p.type === 'month')?.value);
		const year = parts.find((p) => p.type === 'year')?.value;
		memberSince = `Member since ${MONTHS[month - 1]} ${year}`;
	}

	return {
		memberSince,
		anilistHref: anilistUrl(account.siteUrl),
		anime: media(anime),
		manga: media(manga),
		titlesError,
		characters: once(fav?.characters?.nodes ?? []).map((c) => person(c, 'character')),
		staff: once(fav?.staff?.nodes ?? []).map((c) => person(c, 'staff')),
		studios: once(fav?.studios?.nodes ?? []).map((s) => ({
			id: s.id,
			name: s.name,
			href: studioHref(s.id)
		}))
	};
}

/** Whether a profile has any favourites to show (or a failure to say so). */
export function hasFavourites(view: ProfileView): boolean {
	return !!(
		view.titlesError ||
		view.anime.length ||
		view.manga.length ||
		view.characters.length ||
		view.staff.length ||
		view.studios.length
	);
}
