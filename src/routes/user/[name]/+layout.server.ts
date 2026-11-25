import { fetchUserProfile } from '#lib/anilist/client.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import { userMeta } from '#lib/seo.ts';
import type { LayoutServerLoad } from './$types';

// Who they are and their favourites, signed out, so a shared link (to any
// tab) previews with their name and avatar. Their lists load in the browser.
export const load: LayoutServerLoad = async (event) => {
	const profile = await loadPublic(event, () =>
		fetchUserProfile(event.params.name, { signedIn: false })
	);
	return { profile, meta: profile && userMeta(profile.account) };
};
