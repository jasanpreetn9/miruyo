import { browser, dev } from '$app/env';
import { PUBLIC_DEV_ANILIST_TOKEN } from '$app/env/public';
import {
	fetchUnreadCount,
	fetchViewer,
	isAniListError,
	updateViewerSettings,
	type ViewerSettings,
	onUnauthorized,
	setToken as apiSetToken,
	logout as apiLogout,
	type AniListUser
} from '#lib/anilist/client.ts';
import { DEFAULT_SCORE_FORMAT } from '#lib/anilist/score.ts';
import type { MediaType, ScoreFormat } from '#lib/anilist/types.ts';
import { RetryCountdown } from '#lib/state/countdown.svelte.ts';
import { list } from '#lib/state/list.svelte.ts';
import { MODE_STORAGE_KEY, TOKEN_STORAGE_KEY } from '#lib/storage-keys.ts';

export type Mode = 'anime' | 'manga';

export function mediaTypeFor(mode: Mode): MediaType {
	return mode === 'anime' ? 'ANIME' : 'MANGA';
}

/**
 * 'in' = logged in, 'loading' = verifying/fetching the viewer, 'error' =
 * couldn't reach AniList to check the token (it's kept, so a retry can
 * recover), 'out' = no AniList account linked. Whether the logged-in user's
 * list is actually empty is page-local data state, not an auth state — see
 * the `isEmpty` derived value in routes/+page.svelte.
 */
export type AuthState = 'in' | 'loading' | 'error' | 'out';

/** How long to wait before re-checking the account after a non-429 failure. */
const NETWORK_RETRY_SECONDS = 15;

/** Why the viewer was signed out without asking — shown once as a notice. */
export type SignOutReason = 'expired';

class SessionState {
	// Auth & Identity
	user = $state<AniListUser | null>(null);
	authState = $state<AuthState>('loading');
	signOutReason = $state<SignOutReason | null>(null);
	/** Why the last viewer fetch failed, when authState is 'error'. */
	loadError = $state('');
	/** Whether that failure was AniList's rate limit (vs. no response). */
	rateLimited = $state(false);
	/** Running while a rate-limited viewer fetch waits to retry. */
	readonly retry = new RetryCountdown();

	// User Preferences (with localStorage defaults)
	mode = $state<Mode>((browser && (localStorage.getItem(MODE_STORAGE_KEY) as Mode)) || 'anime');

	constructor() {
		if (browser) {
			// AniList rejected the stored token (expired or revoked) on any request
			onUnauthorized(() => this.expire());
			this.initSession();
		}
	}

	/** The viewer's AniList setting; off when signed out. */
	get showAdultContent(): boolean {
		return this.user?.options?.displayAdultContent ?? false;
	}

	get scoreFormat(): ScoreFormat {
		return this.user?.mediaListOptions?.scoreFormat ?? DEFAULT_SCORE_FORMAT;
	}

	/** The names of the viewer's custom lists for anime or manga, in their order. */
	customLists(isAnime: boolean): string[] {
		const options = this.user?.mediaListOptions;
		return (isAnime ? options?.animeList : options?.mangaList)?.customLists ?? [];
	}

	/**
	 * Initializes session on client boot.
	 */
	async initSession() {
		// dev: a token from .env signs in when none is stored (signing out clears it until reload)
		if (dev && PUBLIC_DEV_ANILIST_TOKEN && !localStorage.getItem(TOKEN_STORAGE_KEY)) {
			localStorage.setItem(TOKEN_STORAGE_KEY, PUBLIC_DEV_ANILIST_TOKEN);
		}
		const token = localStorage.getItem(TOKEN_STORAGE_KEY);
		if (!token) {
			this.authState = 'out';
			return;
		}

		await this.loadCurrentUser();
	}

	/**
	 * Fetches current AniList Viewer.
	 */
	async loadCurrentUser() {
		this.retry.stop();
		this.authState = 'loading';
		this.loadError = '';
		this.rateLimited = false;
		try {
			this.user = await fetchViewer();
			this.authState = 'in';
			this.signOutReason = null;
			list.sync = true;
		} catch (err) {
			console.error('Failed to load AniList user profile:', err);
			// a rejected token: sign out (onUnauthorized may already have)
			if (isAniListError(err, 'unauthorized')) return this.expire();
			// otherwise AniList couldn't be reached: keep the token so a retry works
			this.authState = 'error';
			this.loadError = err instanceof Error ? err.message : String(err);
			this.rateLimited = isAniListError(err, 'rate-limit');
			// retry on its own: after the rate-limit window, else shortly
			this.retry.start(
				isAniListError(err, 'rate-limit') ? (err.retryAfter ?? 60) : NETWORK_RETRY_SECONDS,
				() => this.loadCurrentUser()
			);
		}
	}

	/**
	 * Store new OAuth token and refresh user.
	 */
	async setToken(token: string) {
		apiSetToken(token);
		await this.loadCurrentUser();
	}

	logout() {
		apiLogout();
		this.retry.stop();
		this.user = null;
		this.authState = 'out';
		this.loadError = '';
		list.sync = false;
		list.clear();
	}

	/** Signed out because AniList stopped accepting the token. */
	expire() {
		this.logout();
		this.signOutReason = 'expired';
	}

	dismissSignOutReason() {
		this.signOutReason = null;
	}

	/**
	 * Saves account settings on AniList (miruyo follows the account rather
	 * than keeping its own copy) and applies the result locally. Throws if
	 * AniList rejects it.
	 */
	async updateSettings(settings: ViewerSettings): Promise<void> {
		const saved = await updateViewerSettings(settings);
		if (!this.user) return;
		const formatChanged =
			saved.mediaListOptions.scoreFormat !== this.user.mediaListOptions?.scoreFormat;
		this.user = {
			...this.user,
			options: { ...this.user.options, ...saved.options },
			mediaListOptions: { ...this.user.mediaListOptions, ...saved.mediaListOptions }
		};
		// entries held locally carry scores in the old format; pages re-seed
		// them (in the new one) on their next load
		if (formatChanged) list.clear();
	}

	/** The bell's count, refreshed without refetching the whole viewer. */
	async refreshUnreadCount() {
		if (this.authState !== 'in') return;
		try {
			this.setUnreadCount(await fetchUnreadCount());
		} catch (err) {
			// the bell keeps its last count; the next refresh tries again
			console.error('Failed to refresh notifications:', err);
		}
	}

	setUnreadCount(count: number) {
		if (this.user && this.user.unreadNotificationCount !== count)
			this.user = { ...this.user, unreadNotificationCount: count };
	}

	setMode(mode: Mode) {
		this.mode = mode;
		if (browser) localStorage.setItem(MODE_STORAGE_KEY, mode);
	}
}

export const session = new SessionState();
