import type { SearchPeopleResponse } from '#lib/anilist/types.ts';
import { studioHref } from './studio-link.ts';

// What else a Browse search matches besides titles: characters (with the
// title they're best known from), staff (with what they do), AniList users
// and, for anime, studios. Each opens its miruyo page.

export interface PersonResult {
	id: number;
	name: string;
	image: string | null;
	/** "Frieren: Beyond Journey's End" / "Voice Actor". */
	sub: string | null;
	href: string;
}

export interface StudioResult {
	id: number;
	name: string;
	href: string;
}

export interface PeopleResults {
	characters: PersonResult[];
	staff: PersonResult[];
	/** AniList users, whose pages are /user/[name]. */
	users: PersonResult[];
	studios: StudioResult[];
}

export function buildPeopleResults(
	data: SearchPeopleResponse,
	{ isAnime, titles }: { isAnime: boolean; titles: 'userPreferred' | 'english' }
): PeopleResults {
	return {
		characters: data.characters.characters.map((c) => {
			const t = c.media?.nodes[0]?.title;
			const title = t
				? titles === 'english'
					? (t.english ?? t.romaji ?? t.userPreferred)
					: (t.userPreferred ?? t.english ?? t.romaji)
				: null;
			return {
				id: c.id,
				name: c.name.userPreferred ?? 'Unknown',
				image: c.image?.large ?? c.image?.medium ?? null,
				sub: title,
				href: `/character/${c.id}`
			};
		}),
		staff: data.staff.staff.map((s) => ({
			id: s.id,
			name: s.name.userPreferred ?? 'Unknown',
			image: s.image?.large ?? s.image?.medium ?? null,
			sub: s.primaryOccupations?.[0] ?? null,
			href: `/staff/${s.id}`
		})),
		// anyone's list is anime and manga both, so users show in either mode
		users: (data.users?.users ?? []).map((u) => ({
			id: u.id,
			name: u.name,
			image: u.avatar?.large ?? u.avatar?.medium ?? null,
			sub: null,
			href: `/user/${encodeURIComponent(u.name)}`
		})),
		// studios make anime; in manga mode they'd only be noise
		studios: isAnime
			? data.studios.studios
					.filter((s) => s.isAnimationStudio)
					.map((s) => ({
						id: s.id,
						name: s.name,
						href: studioHref(s.id)
					}))
			: []
	};
}

/** Whether there's anything besides titles to show. */
export function hasPeople(results: PeopleResults): boolean {
	return !!(
		results.characters.length ||
		results.staff.length ||
		results.users.length ||
		results.studios.length
	);
}
