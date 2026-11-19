import type { MediaListStatus } from '#lib/anilist/types.ts';

/** Menu order, matching the design system's status dropdown. */
export const LIST_STATUSES: MediaListStatus[] = [
	'CURRENT',
	'COMPLETED',
	'PLANNING',
	'PAUSED',
	'DROPPED',
	'REPEATING'
];

export const STATUS_COLOR: Record<MediaListStatus, string> = {
	CURRENT: '#5AB0FF',
	COMPLETED: '#4ED98A',
	PLANNING: '#B3A996',
	PAUSED: '#F5B83D',
	DROPPED: '#FF6B8B',
	REPEATING: '#3DD6D0'
};

const ANIME_LABELS: Record<MediaListStatus, string> = {
	CURRENT: 'Watching',
	COMPLETED: 'Completed',
	PLANNING: 'Planning',
	PAUSED: 'Paused',
	DROPPED: 'Dropped',
	REPEATING: 'Rewatching'
};

const MANGA_LABELS: Record<MediaListStatus, string> = {
	...ANIME_LABELS,
	CURRENT: 'Reading',
	REPEATING: 'Rereading'
};

/** The status verb for the current mode (Watching → Reading, Rewatching → Rereading). */
export function statusLabel(status: MediaListStatus, isAnime: boolean): string {
	return (isAnime ? ANIME_LABELS : MANGA_LABELS)[status];
}

/** Statuses where progress is still moving, so cards and rows expose +1. */
export function isInProgress(status: MediaListStatus): boolean {
	return status === 'CURRENT' || status === 'REPEATING' || status === 'PAUSED';
}
