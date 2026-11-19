import { error } from '@sveltejs/kit';
import { fetchStaff } from '#lib/anilist/client.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import { staffMeta } from '#lib/seo.ts';
import { staffSort } from './sort.ts';
import type { PageServerLoad } from './$types';

// The signed-out details, so the first render (and a link preview) shows the
// person. The page fetches the viewer's own copy in the browser.
export const load: PageServerLoad = async (event) => {
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) error(404, 'Not found');
	const sort = staffSort(event.url.searchParams);
	const staff = await loadPublic(event, () => fetchStaff(id, { signedIn: false, sort }));
	return { staff, sort, meta: staff && staffMeta(staff) };
};
