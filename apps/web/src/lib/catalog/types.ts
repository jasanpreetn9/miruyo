import type { MediaListStatus } from '#lib/anilist/types.ts';

export interface NextAiring {
	ep: number;
	in: string;
	/** Unix seconds — live data only; the mock catalog just has `in`. */
	at?: number;
	day?: string;
	time?: string;
}

export interface MyProgress {
	s: MediaListStatus;
	p: number;
	v?: number;
	sc?: number;
	of?: string;
	pct?: string;
}

export interface Title {
	id: number;
	title: string;
	en?: string;
	type: 'ANIME' | 'MANGA';
	format: string;
	eps?: number | null;
	/** Minutes per episode (anime), when AniList knows. */
	duration?: number;
	ch?: number | null;
	vol?: number | null;
	score: number;
	color: string;
	genres: string[];
	studio?: string;
	author?: string;
	season?: string;
	status: string;
	next?: NextAiring;
	me?: MyProgress;
	adult?: boolean;
	synopsis?: string;
	accent: string;
	/** CSS background: the cover image, or `placeholder` when there's none. */
	cover: string;
	/** A smaller cover for list thumbnails; falls back to `cover`. */
	thumb?: string;
	/** The colour gradient a cover shows until its image loads. */
	placeholder: string;
	/** Image URLs for <CoverImage>, which lazy-loads them. */
	coverUrl?: string;
	thumbUrl?: string;
	/** AniList's 100px-wide cover, offered beside thumbUrl (230px) for small slots. */
	thumbSmallUrl?: string;
	/** True when AniList has no cover image — PosterCard shows a placeholder. */
	coverMissing?: boolean;
	/** CSS background for the wide banner (AniList's bannerImage); many titles have none. */
	banner?: string;
	glow: string;
	tint: string;
	isAnime: boolean;
	unit: 'EP' | 'CH';
	total: number | null;
	countLabel: string;
	short: string;
}
