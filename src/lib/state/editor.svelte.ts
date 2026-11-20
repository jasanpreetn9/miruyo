import type { AniListSavedEntry } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';

export interface EditorTarget {
	title: Title;
	/**
	 * The viewer's full entry, when the caller already has it (the title
	 * page). Left out, the editor fetches it; null means not on the list.
	 */
	entry?: AniListSavedEntry | null;
}

/**
 * The list editor is one app-wide panel/sheet, rendered by the
 * root layout. Any card, row or page opens it with editor.open(title).
 */
class EditorState {
	target = $state<EditorTarget | null>(null);

	open(title: Title, entry?: AniListSavedEntry | null): void {
		this.target = { title, entry };
	}

	close(): void {
		this.target = null;
	}
}

export const editor = new EditorState();
