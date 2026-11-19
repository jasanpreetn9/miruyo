import { goto } from '$app/navigation';
import { page } from '$app/state';

/**
 * "Focus the search box" requests from anywhere (⌘K, the top bar's search
 * pill, the mobile Search tab). Browse owns the box and consumes the request,
 * whether it was already open or is being navigated to.
 */
class SearchFocus {
	pending = $state(false);

	/** Returns whether a request was waiting, and clears it. */
	consume(): boolean {
		const was = this.pending;
		this.pending = false;
		return was;
	}
}

export const searchFocus = new SearchFocus();

export function openSearch({ replace = false, q = '' } = {}): void {
	searchFocus.pending = true;
	// a query (/search?q=…) carries over; otherwise Browse keeps what it has
	if (q.trim()) void goto(`/browse?q=${encodeURIComponent(q.trim())}`, { replace });
	else if (page.url.pathname !== '/browse') void goto('/browse', { replace });
}

/** ⌘K on macOS, Ctrl+K elsewhere. */
export function isSearchShortcut(e: KeyboardEvent): boolean {
	return (e.metaKey || e.ctrlKey) && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'k';
}
