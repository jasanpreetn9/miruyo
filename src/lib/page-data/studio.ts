import { anilistUrl } from '#lib/anilist/adapt.ts';
import type { StudioPage } from '#lib/anilist/types.ts';
import { formatCompact } from './detail.ts';
import { mediaCard, type MediaCard, type PersonOptions } from './person.ts';

// A studio's page (/studio/[id]): what it is, then the titles it made, most
// popular or newest first. Titles it only helped on (as a producer, say) are
// marked, since AniList lists those with its own productions. As on the
// staff and character pages, titles follow the viewer's AniList preference
// when signed in, English otherwise, and 18+ titles only show when the
// account allows them.

export interface StudioTitle {
	key: string;
	media: MediaCard;
	/** "Producer" when it isn't the studio's own production. */
	caption: string | null;
}

export interface StudioContent {
	id: number;
	name: string;
	/** "Animation studio" or "Studio" (a producer or publisher). */
	kind: string;
	/** "20k". */
	favourites: string;
	isFavourite: boolean;
	anilistHref: string;
	titles: StudioTitle[];
	hasMore: boolean;
}

export function createStudioContent(
	studio: StudioPage,
	{ titles = 'userPreferred', adult = false }: PersonOptions = {}
): StudioContent {
	const seen = new Set<number>();
	const list: StudioTitle[] = [];
	for (const edge of studio.media.edges) {
		if ((edge.node.isAdult && !adult) || seen.has(edge.node.id)) continue;
		seen.add(edge.node.id);
		list.push({
			key: String(edge.node.id),
			media: mediaCard(edge.node, titles),
			caption: edge.isMainStudio ? null : 'Producer'
		});
	}
	return {
		id: studio.id,
		name: studio.name,
		kind: studio.isAnimationStudio ? 'Animation studio' : 'Studio',
		favourites: formatCompact(studio.favourites),
		isFavourite: studio.isFavourite,
		anilistHref: anilistUrl(studio.siteUrl, `https://anilist.co/studio/${studio.id}`),
		titles: list,
		hasMore: studio.media.pageInfo.hasNextPage
	};
}
