import type { PersonSort } from '#lib/anilist/client.ts';

/** `?sort=newest` lists the newest titles first; most popular is the default. */
export function studioSort(params: Pick<URLSearchParams, 'get'>): PersonSort {
	return params.get('sort') === 'newest' ? 'START_DATE_DESC' : 'POPULARITY_DESC';
}
