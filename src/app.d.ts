// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { PageMeta } from '#lib/seo.ts';

declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		interface PageData {
			/** A server-rendered page's own share-card and search tags (see #lib/seo.ts). */
			meta?: PageMeta | null;
		}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
