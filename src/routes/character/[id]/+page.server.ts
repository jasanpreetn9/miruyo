import { error } from '@sveltejs/kit';
import { fetchCharacter } from '#lib/anilist/client.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import { characterMeta } from '#lib/seo.ts';
import type { PageServerLoad } from './$types';

// The signed-out details, so the first render (and a link preview) shows the
// character. The page fetches the viewer's own copy in the browser.
export const load: PageServerLoad = async (event) => {
	const id = Number(event.params.id);
	if (!Number.isInteger(id) || id <= 0) error(404, 'Not found');
	const character = await loadPublic(event, () => fetchCharacter(id, { signedIn: false }));
	return { character, meta: character && characterMeta(character) };
};
