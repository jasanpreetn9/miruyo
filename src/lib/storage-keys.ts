// Single source of truth for localStorage keys used by the AniList auth flow
// and view preferences — import these instead of repeating string literals
// across anilist/client.ts / session.svelte.ts / the OAuth callback route.
export const TOKEN_STORAGE_KEY = 'anilist_token';
export const MODE_STORAGE_KEY = 'miruyo_mode';
/** Set once the first-run setup (/welcome) has been finished or skipped. */
export const ONBOARDED_STORAGE_KEY = 'miruyo_onboarded';
/** `${userId}:${mode}` pairs whose empty-list quick-pick was skipped. */
export const QUICK_PICK_SKIPPED_STORAGE_KEY = 'miruyo_quick_pick_skipped';
/** My List's table/grid choice ('table' | 'grid'), shared by every tab. */
export const LIST_VIEW_STORAGE_KEY = 'miruyo_list_view';
/** The season chart's view ('cards' | 'posters'). */
export const SEASON_VIEW_STORAGE_KEY = 'miruyo_season_view';
/** Media ids hidden from For You with "Not this" (a JSON array). */
export const FOR_YOU_DISMISSED_STORAGE_KEY = 'miruyo_for_you_dismissed';
/** For You's "Tune picks" settings (JSON). */
export const FOR_YOU_TUNE_STORAGE_KEY = 'miruyo_for_you_tune';
/** sessionStorage: what AniList last said about its rate limit, so a reload remembers. */
export const RATE_LIMIT_STORAGE_KEY = 'miruyo_rate_limit';
/** sessionStorage: the OAuth `state` of the sign-in this tab started. */
export const OAUTH_STATE_STORAGE_KEY = 'miruyo_oauth_state';
