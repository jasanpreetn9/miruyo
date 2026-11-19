import { error } from '@sveltejs/kit';
import { fetchStudio } from '#lib/anilist/client.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import { studioMeta } from '#lib/seo.ts';
import { studioSort } from './sort.ts';
import type { PageServerLoad } from './$types';

// The signed-out details, so the first render (and a link preview) shows the
// studio. The page fetches the viewer's own copy in the browser.
export const load: PageServerLoad = async (event) => {
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) error(404, 'Not found');
	const sort = studioSort(event.url.searchParams);
	const studio = await loadPublic(event, () => fetchStudio(id, { signedIn: false, sort }));
	return { studio, sort, meta: studio && studioMeta(studio) };
};
