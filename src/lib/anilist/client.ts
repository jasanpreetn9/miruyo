import { browser } from '$app/env';
import { PUBLIC_ANILIST_CLIENT_ID } from '$app/env/public';
import {
	ACTIVITY_HISTORY_QUERY,
	BROWSE_COLLECTIONS_QUERY,
	BROWSE_QUERY,
	CHARACTER_APPEARANCES_QUERY,
	CHARACTER_PAGE_QUERY,
	DELETE_ENTRY_MUTATION,
	DETAIL_QUERY,
	ENTRY_QUERY,
	TOGGLE_FAVOURITE_MUTATION,
	AIRING_WEEK_QUERY,
	SEASON_CHART_QUERY,
	SEASON_LEFTOVERS_QUERY,
	LIST_COLLECTION_QUERY,
	NEW_MANGA_QUERY,
	NOTIFICATIONS_QUERY,
	TOGGLE_FOLLOW_MUTATION,
	USER_LIST_QUERY,
	USER_PROFILE_QUERY,
	forYouQuery,
	forYouRelationsQuery,
	FAVOURITE_MEDIA_QUERY,
	UNREAD_COUNT_QUERY,
	LIST_ENTRIES_QUERY,
	HOME_FEED_QUERY,
	HOME_LIST_QUERY,
	PUBLIC_TRENDING_QUERY,
	SAVE_ENTRY_MUTATION,
	SEARCH_PEOPLE_QUERY,
	STAFF_CREDITS_QUERY,
	STAFF_PAGE_QUERY,
	STUDIO_MEDIA_QUERY,
	STUDIO_PAGE_QUERY,
	STAFF_VOICE_ROLES_QUERY,
	TITLE_STATS_QUERY,
	UPDATE_SETTINGS_MUTATION,
	VIEWER_COUNTS_QUERY,
	VIEWER_QUERY
} from './queries.ts';
import { RATE_LIMIT_STORAGE_KEY, TOKEN_STORAGE_KEY } from '#lib/storage-keys.ts';
import { Pacer } from './pacer.ts';
import type {
	ActivityDay,
	ActivityHistoryResponse,
	AniListDate,
	AniListMedia,
	AniListSavedEntry,
	AniListUser,
	BrowseCollectionsResponse,
	BrowseResponse,
	CharacterAppearances,
	CharacterPerson,
	DetailMedia,
	DetailResponse,
	HomeFeedResponse,
	HomeListResponse,
	AiringSlot,
	AiringWeekResponse,
	CollectionEntry,
	ListCollectionResponse,
	ListEntriesResponse,
	MediaListStatus,
	MediaSeason,
	MediaType,
	NotificationsResponse,
	ProfileAccount,
	SearchPeopleResponse,
	UserAccount,
	Profile,
	AniListNotification,
	PublicTrendingResponse,
	ScoreFormat,
	SeasonChartResponse,
	SeasonLeftoversResponse,
	SeasonMedia,
	StaffCredits,
	StudioMedia,
	StudioPage,
	StaffPerson,
	StaffVoiceRoles,
	TitleLanguage,
	TitleStatsResponse,
	ViewerCountsResponse
} from './types.ts';

export type { AniListUser };

/** The AniList API client to sign in with; see src/env.ts. */
export const clientId = PUBLIC_ANILIST_CLIENT_ID;

const ENDPOINT = 'https://graphql.anilist.co';

/** Used when a 429 doesn't say how long to wait. AniList's window is a minute. */
const DEFAULT_RETRY_AFTER = 60;

interface GraphQLResponse<T> {
	data?: T;
	errors?: Array<{ message: string; status?: number }>;
}

/**
 * 'rate-limit' = 429 (or no response while online, which is how a 429 looks
 * in the browser), retry after `retryAfter` seconds. 'unauthorized' = the
 * token we sent was rejected (expired or revoked). 'network' = no response
 * while offline. 'api' = anything else AniList reported.
 */
export type AniListErrorKind = 'rate-limit' | 'unauthorized' | 'network' | 'api';

export class AniListError extends Error {
	constructor(
		message: string,
		readonly kind: AniListErrorKind,
		readonly status?: number,
		/** Seconds; only set for 'rate-limit'. */
		readonly retryAfter?: number
	) {
		super(message);
		this.name = 'AniListError';
	}
}

export function isAniListError(err: unknown, kind?: AniListErrorKind): err is AniListError {
	return err instanceof AniListError && (kind === undefined || err.kind === kind);
}

let unauthorizedHandler: (() => void) | null = null;

/** Called whenever AniList rejects the stored token — session signs out. */
export function onUnauthorized(handler: (() => void) | null): void {
	unauthorizedHandler = handler;
}

function storedToken(): string | null {
	return browser ? localStorage.getItem(TOKEN_STORAGE_KEY) : null;
}

export function setToken(newToken: string | null): void {
	clearCache();
	if (browser) {
		if (newToken) {
			localStorage.setItem(TOKEN_STORAGE_KEY, newToken);
		} else {
			localStorage.removeItem(TOKEN_STORAGE_KEY);
		}
	}
}

export function logout(): void {
	setToken(null);
}

/** Seconds to wait, from Retry-After or (failing that) X-RateLimit-Reset. */
function retryAfterSeconds(res: Response): number {
	const retryAfter = Number(res.headers.get('Retry-After'));
	if (Number.isFinite(retryAfter) && retryAfter > 0) return Math.ceil(retryAfter);
	const reset = Number(res.headers.get('X-RateLimit-Reset'));
	if (Number.isFinite(reset) && reset > 0) {
		const seconds = Math.ceil(reset - Date.now() / 1000);
		if (seconds > 0) return seconds;
	}
	return DEFAULT_RETRY_AFTER;
}

/**
 * Paces this tab's requests to AniList's rate limit (pacer.ts). Browser only:
 * the server renders a few public pages, whose render shouldn't wait.
 */
const pacer = browser
	? new Pacer(undefined, undefined, { storage: sessionStorage, key: RATE_LIMIT_STORAGE_KEY })
	: null;

/** AniList's wording for a token it no longer accepts (sent with a 400). */
const INVALID_TOKEN_MESSAGE = /invalid token/i;

/**
 * `authToken`: omit to use the stored token, pass `null` to send the request
 * without one (public queries).
 */
export async function anilistQuery<T>(
	query: string,
	variables: Record<string, unknown> = {},
	authToken?: string | null
): Promise<T> {
	const token = authToken === undefined ? storedToken() : authToken;

	const headers: HeadersInit = {
		'Content-Type': 'application/json',
		Accept: 'application/json'
	};

	if (token) {
		headers['Authorization'] = `Bearer ${token}`;
	}

	await pacer?.slot();
	let res: Response;
	try {
		res = await fetch(ENDPOINT, {
			method: 'POST',
			headers,
			body: JSON.stringify({ query, variables })
		});
	} catch (err) {
		pacer?.settle(null);
		// AniList's 429s carry no CORS headers, so in the browser its rate limit
		// arrives as a failed fetch with nothing to read. While the device is
		// online that's the likely cause, so wait out the window and retry
		// rather than offer a Retry that only hits the limit again.
		if (typeof navigator !== 'undefined' && navigator.onLine) {
			pacer?.limited();
			throw new AniListError(
				'AniList is busy right now (no response, most likely its rate limit).',
				'rate-limit',
				undefined,
				DEFAULT_RETRY_AFTER
			);
		}
		throw new AniListError(
			err instanceof Error ? err.message : 'Could not reach AniList.',
			'network'
		);
	}

	pacer?.settle(res.headers);

	// AniList returns a JSON body with real error detail even on 4xx/5xx
	// (e.g. a validation error on 400, a rate-limit message on 429) — parse
	// it before giving up, instead of discarding that detail for a generic
	// "status N" message.
	let json: GraphQLResponse<T> | null = null;
	try {
		json = await res.json();
	} catch {
		// non-JSON body (e.g. a plain-text 5xx from an upstream proxy)
	}

	const errors = json?.errors ?? [];
	const message = errors.length
		? errors.map((e) => e.message).join('; ')
		: `AniList request failed with status ${res.status}.`;

	if (res.status === 429 || errors.some((e) => e.status === 429)) {
		const wait = retryAfterSeconds(res);
		pacer?.pause(wait);
		throw new AniListError(message, 'rate-limit', 429, wait);
	}

	// AniList reports a bad token as a 400 with an "Invalid token" message as
	// often as a 401, so check both. Other permission errors ("Unauthorized"
	// on a 400/403 for one resource) are about that request, not the token,
	// and must not sign the viewer out.
	if (
		token &&
		(res.status === 401 ||
			errors.some((e) => e.status === 401 || INVALID_TOKEN_MESSAGE.test(e.message)))
	) {
		unauthorizedHandler?.();
		throw new AniListError(message, 'unauthorized', 401);
	}

	if (errors.length || !res.ok) {
		throw new AniListError(message, 'api', res.status);
	}

	if (!json?.data) {
		throw new AniListError('No data returned from AniList API.', 'api', res.status);
	}

	return json.data;
}

// ── Request cache ──
// AniList allows ~90 requests a minute (sometimes cut to 30), so identical
// queries share one in-flight request and reuse the result for a short while
// (and the pacer above spaces requests out as the limit nears).

/** How long a successful response is reused, in ms. */
export const CACHE_TTL = 60_000;

interface CacheEntry {
	promise: Promise<unknown>;
	/** The token the request was sent with ('' for public requests). */
	token: string;
	/** Infinity while in flight; 0 once a list edit made it stale. */
	expires: number;
	/** Served stale while a newer copy loads (staleWhileRevalidate). */
	swr: boolean;
	/** The background request replacing it, if one is running. */
	refresh?: Promise<unknown>;
}

const cache = new Map<string, CacheEntry>();

// ── Stale lists and local edits ──
// A list collection is large (seconds to load for a long list), so once it
// has loaded it's served at once, even past its TTL or after an edit, while a
// newer copy loads behind it. A copy can then predate a local edit: each
// response remembers the edit clock (the list store's stamp()) from when it
// was requested, and whoever seeds the store from it passes that on, so a
// stale copy never undoes an edit.

let editClock: () => number = () => 0;
/** The list store hands over its stamp(), read when each request starts. */
export function useEditClock(clock: () => number): void {
	editClock = clock;
}

const stamps = new WeakMap<object, number>();
/**
 * The edit clock when `data` was requested, for ListStore.seed(). Unknown
 * data counts as older than every edit, which keeps every local value.
 */
export function requestStamp(data: object): number {
	return stamps.get(data) ?? 0;
}

const refreshListeners = new Set<() => void>();
/** Called when a stale response has been replaced in the background. */
export function onRefreshed(listener: () => void): () => void {
	refreshListeners.add(listener);
	return () => refreshListeners.delete(listener);
}

/**
 * Past this many entries, expired ones are dropped. A tab only ever holds a
 * few dozen, but on the server (which renders public pages) every title
 * visited would otherwise stay in memory.
 */
const CACHE_PRUNE_AT = 200;

function pruneCache(): void {
	const now = Date.now();
	for (const [key, entry] of cache) {
		if (entry.expires <= now) cache.delete(key);
	}
}

/** Drops every cached response — called on sign-in/out. */
export function clearCache(): void {
	cache.clear();
}

/**
 * Drops the responses fetched with a token — called after a list edit, since
 * those carry list state. Public responses (trending) don't, so they stay
 * cached and repeated edits don't burn through the rate limit. A list
 * collection is kept but marked stale: it's served while a newer one loads.
 * `lists`: drop those too, when an old copy would be wrong rather than old
 * (a new score format changes every score on it).
 */
function clearViewerCache({ lists = false }: { lists?: boolean } = {}): void {
	for (const [key, entry] of cache) {
		if (!entry.token) continue;
		if (entry.swr && !lists) {
			if (entry.expires !== Infinity) entry.expires = 0;
		} else cache.delete(key);
	}
}

interface CachedQueryOptions {
	authToken?: string | null;
	ttl?: number;
	/**
	 * Once loaded, serve the last response at once, even when expired or made
	 * stale by an edit, and load a newer one behind it (onRefreshed says when).
	 */
	staleWhileRevalidate?: boolean;
	/** Wait for a new response (a Retry, or a refresh the viewer asked for). */
	fresh?: boolean;
}

export function cachedQuery<T>(
	query: string,
	variables: Record<string, unknown> = {},
	{
		authToken,
		ttl = CACHE_TTL,
		staleWhileRevalidate = false,
		fresh = false
	}: CachedQueryOptions = {}
): Promise<T> {
	const token = authToken === undefined ? storedToken() : authToken;
	// the token is part of the key: the same query returns different data
	// (list state, preferred titles) for different viewers
	const key = JSON.stringify([token ?? '', query, variables]);

	const hit = cache.get(key);
	const settled = hit && hit.expires !== Infinity;
	if (hit && !settled) return hit.promise as Promise<T>;
	if (hit && hit.expires > Date.now() && !fresh) return hit.promise as Promise<T>;
	if (hit?.swr && settled) {
		const refresh = (hit.refresh ??= revalidate(key, hit, query, variables, token, ttl));
		return (fresh ? refresh : hit.promise) as Promise<T>;
	}

	const promise = request<T>(query, variables, token, ttl, key);
	if (cache.size >= CACHE_PRUNE_AT) pruneCache();
	cache.set(key, { promise, token: token ?? '', expires: Infinity, swr: staleWhileRevalidate });
	return promise;
}

/** A first request for `key`: it settles the entry it's stored in. */
function request<T>(
	query: string,
	variables: Record<string, unknown>,
	token: string | null,
	ttl: number,
	key: string
): Promise<T> {
	const stamp = editClock();
	const promise: Promise<T> = anilistQuery<T>(query, variables, token).then(
		(data) => {
			if (data && typeof data === 'object') stamps.set(data, stamp);
			const entry = cache.get(key);
			// an edit while it loaded: it's already stale
			if (entry?.promise === promise) entry.expires = stamp < editClock() ? 0 : Date.now() + ttl;
			return data;
		},
		(err) => {
			if (cache.get(key)?.promise === promise) cache.delete(key);
			throw err;
		}
	);
	return promise;
}

/**
 * Loads a newer copy of a stale entry and swaps it in. A failure keeps the
 * stale copy (the next read tries again) and only rejects for a `fresh` read.
 */
function revalidate(
	key: string,
	entry: CacheEntry,
	query: string,
	variables: Record<string, unknown>,
	token: string | null,
	ttl: number
): Promise<unknown> {
	const stamp = editClock();
	const refresh = anilistQuery<unknown>(query, variables, token).then(
		(data) => {
			// signed out (or replaced) meanwhile: leave the cache alone
			if (cache.get(key) !== entry) return data;
			if (data && typeof data === 'object') stamps.set(data, stamp);
			entry.promise = Promise.resolve(data);
			entry.expires = stamp < editClock() ? 0 : Date.now() + ttl;
			entry.refresh = undefined;
			for (const listener of refreshListeners) listener();
			return data;
		},
		(err) => {
			if (cache.get(key) === entry) entry.refresh = undefined;
			throw err;
		}
	);
	// nobody may be waiting on it
	refresh.catch(() => {});
	return refresh;
}

// ── List editing ──

/** Fields of a list entry that can be saved. Omitted fields are left as they are. */
export interface EntryInput {
	status?: MediaListStatus;
	progress?: number;
	progressVolumes?: number;
	/** In the viewer's own scoreFormat (see anilist/score.ts). 0 clears it. */
	score?: number;
	/** Pass a date with all-null parts to clear it. */
	startedAt?: AniListDate;
	completedAt?: AniListDate;
	repeat?: number;
	notes?: string;
	private?: boolean;
	/** Higher comes first in Up next (the mobile app's Planning order). */
	priority?: number;
	/** The names of every custom list it should be on (the whole set, not a change). */
	customLists?: string[];
}

export async function saveEntry(mediaId: number, input: EntryInput): Promise<AniListSavedEntry> {
	const variables: Record<string, unknown> = { mediaId };
	for (const [field, value] of Object.entries(input)) {
		if (value !== undefined) variables[field] = value;
	}
	const data = await anilistQuery<{ SaveMediaListEntry: AniListSavedEntry }>(
		SAVE_ENTRY_MUTATION,
		variables
	);
	clearViewerCache();
	return data.SaveMediaListEntry;
}

/** `entryId` is the list entry's own id, not the media id. */
export async function deleteEntry(entryId: number): Promise<boolean> {
	const data = await anilistQuery<{ DeleteMediaListEntry: { deleted: boolean } }>(
		DELETE_ENTRY_MUTATION,
		{ id: entryId }
	);
	clearViewerCache();
	return data.DeleteMediaListEntry.deleted;
}

export async function fetchViewer(): Promise<AniListUser> {
	const data = await anilistQuery<{ Viewer: AniListUser }>(VIEWER_QUERY);
	return data.Viewer;
}

/**
 * A profile by name: anyone's, yours included. Signed in, it says whether
 * the viewer follows them; the favourite titles carry the viewer's own list
 * state.
 */
export async function fetchUserProfile(
	name: string,
	{ signedIn }: { signedIn: boolean }
): Promise<Profile<UserAccount>> {
	// up to 25 of each, for the Favourites tab
	const { User: account } = await cachedQuery<{ User: UserAccount }>(
		USER_PROFILE_QUERY,
		{ name, perPage: 25, peoplePerPage: 25 },
		signedIn ? {} : { authToken: null }
	);
	return withFavouriteTitles(account);
}

/** Fills in an account's favourite titles, which the profile queries only list by id. */
async function withFavouriteTitles<A extends ProfileAccount>(account: A): Promise<Profile<A>> {
	const ids = (key: 'anime' | 'manga') => account.favourites?.[key]?.nodes.map((n) => n.id) ?? [];
	const animeIds = ids('anime');
	const mangaIds = ids('manga');
	const all = [...animeIds, ...mangaIds];
	if (!all.length) return { account, anime: [], manga: [], titlesError: null };
	try {
		const data = await cachedQuery<{ Page: { media: AniListMedia[] } }>(FAVOURITE_MEDIA_QUERY, {
			ids: all
		});
		const byId = new Map(data.Page.media.map((m) => [m.id, m]));
		// id_in doesn't keep the favourites' order, so put it back
		const inOrder = (list: number[]) =>
			list.map((id) => byId.get(id)).filter((m): m is AniListMedia => !!m);
		return { account, anime: inOrder(animeIds), manga: inOrder(mangaIds), titlesError: null };
	} catch (err) {
		if (isAniListError(err, 'unauthorized')) throw err;
		return {
			account,
			anime: null,
			manga: null,
			titlesError: err instanceof Error ? err.message : String(err)
		};
	}
}

/** AniList's recommendations for each seed id, by seed id. */
export async function fetchRecommendations(
	seedIds: number[]
): Promise<Map<number, Array<{ rating: number; media: AniListMedia }>>> {
	const result = new Map<number, Array<{ rating: number; media: AniListMedia }>>();
	if (!seedIds.length) return result;
	type Seed = {
		id: number;
		recommendations: {
			nodes: Array<{ rating: number | null; mediaRecommendation: AniListMedia | null }>;
		} | null;
	} | null;
	const data = await cachedQuery<Record<string, Seed>>(forYouQuery(seedIds));
	for (const seed of Object.values(data)) {
		if (!seed) continue;
		result.set(
			seed.id,
			(seed.recommendations?.nodes ?? []).flatMap((n) =>
				n.mediaRecommendation ? [{ rating: n.rating ?? 0, media: n.mediaRecommendation }] : []
			)
		);
	}
	return result;
}

/**
 * The related titles of For You's cross seeds (titles you loved on your other
 * list), by seed id; For You keeps their source or adaptations.
 */
export async function fetchRelations(
	seedIds: number[]
): Promise<Map<number, Array<{ relationType: string; media: AniListMedia }>>> {
	const result = new Map<number, Array<{ relationType: string; media: AniListMedia }>>();
	if (!seedIds.length) return result;
	type Seed = {
		id: number;
		relations: {
			edges: Array<{ relationType: string | null; node: AniListMedia | null }>;
		} | null;
	} | null;
	const data = await cachedQuery<Record<string, Seed>>(forYouRelationsQuery(seedIds));
	for (const seed of Object.values(data)) {
		if (!seed) continue;
		result.set(
			seed.id,
			(seed.relations?.edges ?? []).flatMap((e) =>
				e.node && e.relationType ? [{ relationType: e.relationType, media: e.node }] : []
			)
		);
	}
	return result;
}

/** The viewer's latest notifications, newest first. Marks them read on AniList. */
export async function fetchNotifications(perPage = 25): Promise<AniListNotification[]> {
	const data = await anilistQuery<NotificationsResponse>(NOTIFICATIONS_QUERY, { perPage });
	return data.Page.notifications;
}

export async function fetchUnreadCount(): Promise<number> {
	const data = await anilistQuery<{ Viewer: { unreadNotificationCount: number } }>(
		UNREAD_COUNT_QUERY
	);
	return data.Viewer.unreadNotificationCount;
}

/** The anime season AniList expects for "popular this season", as of `date`. */
function currentSeason(date = new Date()): { season: MediaSeason; year: number } {
	const month = date.getMonth(); // 0-11
	const year = date.getFullYear();
	if (month === 11) return { season: 'WINTER', year: year + 1 };
	if (month <= 1) return { season: 'WINTER', year };
	if (month <= 4) return { season: 'SPRING', year };
	if (month <= 7) return { season: 'SUMMER', year };
	return { season: 'FALL', year };
}

const SEASON_ORDER: MediaSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

function nextSeason(season: MediaSeason, year: number): { season: MediaSeason; year: number } {
	const i = SEASON_ORDER.indexOf(season);
	return i === SEASON_ORDER.length - 1
		? { season: SEASON_ORDER[0], year: year + 1 }
		: { season: SEASON_ORDER[i + 1], year };
}

/** The viewer's in-progress list for Home (Continue + hero). */
export async function fetchHomeList(userId: number, type: MediaType): Promise<HomeListResponse> {
	return cachedQuery<HomeListResponse>(HOME_LIST_QUERY, { userId, type, perPage: 10 });
}

/** Home's trending / popular / upcoming rows, with the viewer's list entry on each title. */
export async function fetchHomeFeed(type: MediaType): Promise<HomeFeedResponse> {
	// AniList's season/seasonYear data is unreliable for manga, so only
	// constrain "popular this season"/"upcoming" by season for anime —
	// for manga they fall back to "currently releasing"/"not yet released"
	// sorted by popularity with no season filter.
	const isAnime = type === 'ANIME';
	const current = currentSeason();
	const next = nextSeason(current.season, current.year);

	// No isAdult argument — AniList applies the authenticated viewer's own
	// account setting (Viewer.options.displayAdultContent) to these fields,
	// so miruyo doesn't duplicate that preference.
	return cachedQuery<HomeFeedResponse>(HOME_FEED_QUERY, {
		type,
		season: isAnime ? current.season : null,
		seasonYear: isAnime ? current.year : null,
		nextSeason: isAnime ? next.season : null,
		nextSeasonYear: isAnime ? next.year : null,
		perPage: 10
	});
}

/** How many anime and manga are on the viewer's list (first-run setup). */
export async function fetchViewerCounts(): Promise<{ anime: number; manga: number }> {
	const data = await anilistQuery<ViewerCountsResponse>(VIEWER_COUNTS_QUERY);
	const stats = data.Viewer.statistics;
	return { anime: stats?.anime?.count ?? 0, manga: stats?.manga?.count ?? 0 };
}

export interface ViewerSettings {
	titleLanguage?: TitleLanguage;
	displayAdultContent?: boolean;
	airingNotifications?: boolean;
	scoreFormat?: ScoreFormat;
}

/** The account settings miruyo reads, as UpdateUser returns them. */
export type SavedViewerSettings = Required<Pick<AniListUser, 'options' | 'mediaListOptions'>>;

/**
 * Saves account settings on AniList itself — miruyo follows the account's
 * settings rather than keeping its own copy. Drops cached viewer responses,
 * since titles, 18+ filtering and scores change with them.
 */
export async function updateViewerSettings(settings: ViewerSettings): Promise<SavedViewerSettings> {
	const variables: Record<string, unknown> = {};
	for (const [field, value] of Object.entries(settings)) {
		if (value !== undefined) variables[field] = value;
	}
	const data = await anilistQuery<{ UpdateUser: SavedViewerSettings }>(
		UPDATE_SETTINGS_MUTATION,
		variables
	);
	// the list's scores come in the viewer's score format: an old copy is wrong
	clearViewerCache({ lists: true });
	return data.UpdateUser;
}

/**
 * One page of Browse results. Sent with the viewer's token when signed in
 * (list state, the onList filter, their title language); without one when
 * signed out.
 */
export async function fetchBrowse(
	variables: Record<string, unknown>,
	{ signedIn }: { signedIn: boolean }
): Promise<BrowseResponse['Page']> {
	const data = await cachedQuery<BrowseResponse>(
		BROWSE_QUERY,
		variables,
		signedIn ? {} : { authToken: null }
	);
	return data.Page;
}

/** The characters, staff and studios a Browse search matches; public, so no token. */
export async function fetchSearchPeople(search: string): Promise<SearchPeopleResponse> {
	return cachedQuery<SearchPeopleResponse>(SEARCH_PEOPLE_QUERY, { search }, { authToken: null });
}

/**
 * Everything the title page shows. Signed in, it carries the viewer's own
 * entry and favourite state; signed out it's sent without a token.
 */
export async function fetchDetail(
	id: number,
	{ signedIn }: { signedIn: boolean }
): Promise<DetailMedia> {
	const data = await cachedQuery<DetailResponse>(
		DETAIL_QUERY,
		{ id },
		signedIn ? {} : { authToken: null }
	);
	return data.Media;
}

/** A title's Stats tab: its score and status breakdowns and rankings. Public, so no token. */
export async function fetchTitleStats(id: number): Promise<TitleStatsResponse['Media']> {
	const data = await cachedQuery<TitleStatsResponse>(
		TITLE_STATS_QUERY,
		{ id },
		{ authToken: null }
	);
	return data.Media;
}

/** How a voice actor's roles and someone's credits are ordered. */
export type PersonSort = 'POPULARITY_DESC' | 'START_DATE_DESC';

/**
 * A staff page: the person, then the first page of their voice roles and
 * credits. Signed in, it carries the viewer's favourite state.
 */
export async function fetchStaff(
	id: number,
	{ signedIn, sort }: { signedIn: boolean; sort: PersonSort }
): Promise<StaffPerson> {
	const data = await cachedQuery<{ Staff: StaffPerson }>(
		STAFF_PAGE_QUERY,
		{ id, sort: [sort] },
		signedIn ? {} : { authToken: null }
	);
	return data.Staff;
}

/** Another page of a voice actor's roles; the same for everyone, so sent without a token. */
export async function fetchStaffVoiceRoles(
	id: number,
	page: number,
	sort: PersonSort
): Promise<StaffVoiceRoles> {
	const data = await cachedQuery<{ Staff: { characterMedia: StaffVoiceRoles } }>(
		STAFF_VOICE_ROLES_QUERY,
		{ id, page, sort: [sort] },
		{ authToken: null }
	);
	return data.Staff.characterMedia;
}

/** Another page of someone's credits; sent without a token. */
export async function fetchStaffCredits(
	id: number,
	page: number,
	sort: PersonSort
): Promise<StaffCredits> {
	const data = await cachedQuery<{ Staff: { staffMedia: StaffCredits } }>(
		STAFF_CREDITS_QUERY,
		{ id, page, sort: [sort] },
		{ authToken: null }
	);
	return data.Staff.staffMedia;
}

/**
 * A studio page: the studio, then the first page of its titles. Signed in,
 * it carries the viewer's favourite state.
 */
export async function fetchStudio(
	id: number,
	{ signedIn, sort }: { signedIn: boolean; sort: PersonSort }
): Promise<StudioPage> {
	const data = await cachedQuery<{ Studio: StudioPage }>(
		STUDIO_PAGE_QUERY,
		{ id, sort: [sort] },
		signedIn ? {} : { authToken: null }
	);
	return data.Studio;
}

/** Another page of a studio's titles; sent without a token. */
export async function fetchStudioMedia(
	id: number,
	page: number,
	sort: PersonSort
): Promise<StudioMedia> {
	const data = await cachedQuery<{ Studio: { media: StudioMedia } }>(
		STUDIO_MEDIA_QUERY,
		{ id, page, sort: [sort] },
		{ authToken: null }
	);
	return data.Studio.media;
}

/**
 * A character page: the character, then the first page of the titles
 * they're in. Signed in, it carries the viewer's favourite state.
 */
export async function fetchCharacter(
	id: number,
	{ signedIn }: { signedIn: boolean }
): Promise<CharacterPerson> {
	const data = await cachedQuery<{ Character: CharacterPerson }>(
		CHARACTER_PAGE_QUERY,
		{ id },
		signedIn ? {} : { authToken: null }
	);
	return data.Character;
}

/** Another page of the titles a character is in; sent without a token. */
export async function fetchCharacterAppearances(
	id: number,
	page: number
): Promise<CharacterAppearances> {
	const data = await cachedQuery<{ Character: { media: CharacterAppearances } }>(
		CHARACTER_APPEARANCES_QUERY,
		{ id, page },
		{ authToken: null }
	);
	return data.Character.media;
}

/** The viewer's full entry for a title, or null when it isn't on their list. */
export async function fetchEntry(
	userId: number,
	mediaId: number
): Promise<AniListSavedEntry | null> {
	try {
		const data = await anilistQuery<{ MediaList: AniListSavedEntry | null }>(ENTRY_QUERY, {
			userId,
			mediaId
		});
		return data.MediaList;
	} catch (err) {
		// AniList answers "not on the list" with a 404
		if (isAniListError(err, 'api') && err.status === 404) return null;
		throw err;
	}
}

/** Favourites (or un-favourites) a title on the viewer's AniList profile. */
/** What can be a favourite: a title, a character or a staff member. */
export type FavouriteKind = MediaType | 'CHARACTER' | 'STAFF' | 'STUDIO';

const FAVOURITE_ID = {
	ANIME: 'animeId',
	MANGA: 'mangaId',
	CHARACTER: 'characterId',
	STAFF: 'staffId',
	STUDIO: 'studioId'
} as const satisfies Record<FavouriteKind, string>;

export async function toggleFavourite(kind: FavouriteKind, id: number): Promise<void> {
	await anilistQuery(TOGGLE_FAVOURITE_MUTATION, { [FAVOURITE_ID[kind]]: id });
	clearViewerCache();
}

/**
 * The viewer's whole list for one type. Custom lists repeat entries already
 * in a status list, so they're skipped; a title appears once.
 */
/** Served at once once loaded, refreshed behind (see staleWhileRevalidate). */
const LIST_CACHE = { staleWhileRevalidate: true } as const;

export async function fetchListCollection(
	userId: number,
	type: MediaType,
	{ fresh = false }: { fresh?: boolean } = {}
): Promise<CollectionEntry[]> {
	const data = await cachedQuery<ListCollectionResponse>(
		LIST_COLLECTION_QUERY,
		{ userId, type },
		{ ...LIST_CACHE, fresh }
	);
	const seen = new Set<number>();
	const entries: CollectionEntry[] = [];
	// status lists first; custom lists add only what they alone hold (an entry
	// set to "hide from status lists" on AniList is in a custom list only)
	const lists = [...(data.MediaListCollection?.lists ?? [])].sort(
		(a, b) => Number(a.isCustomList) - Number(b.isCustomList)
	);
	for (const group of lists) {
		for (const entry of group.entries) {
			if (seen.has(entry.mediaId)) continue;
			seen.add(entry.mediaId);
			entries.push(entry);
		}
	}
	// whoever seeds the list store from these needs to know how old they are
	stamps.set(entries, requestStamp(data));
	return entries;
}

/** One of your own lists on AniList ("Rewatch someday"): its name and the titles on it. */
export interface CustomList {
	name: string;
	mediaIds: number[];
}

/**
 * Your custom lists, in AniList's order, and the titles that are only on
 * them (set to "hide from status lists"). The same request (and cache) as
 * fetchListCollection, so asking for both costs one.
 */
export async function fetchCustomLists(
	userId: number,
	type: MediaType,
	{ fresh = false }: { fresh?: boolean } = {}
): Promise<{ lists: CustomList[]; hidden: number[] }> {
	const data = await cachedQuery<ListCollectionResponse>(
		LIST_COLLECTION_QUERY,
		{ userId, type },
		{ ...LIST_CACHE, fresh }
	);
	const groups = data.MediaListCollection?.lists ?? [];
	const onStatus = new Set(
		groups.filter((l) => !l.isCustomList).flatMap((l) => l.entries.map((e) => e.mediaId))
	);
	const lists = groups
		.filter((l) => l.isCustomList && l.entries.length)
		.map((l) => ({ name: l.name, mediaIds: l.entries.map((e) => e.mediaId) }));
	const hidden = [...new Set(lists.flatMap((l) => l.mediaIds))].filter((id) => !onStatus.has(id));
	return { lists, hidden };
}

/**
 * Someone else's list as anyone sees it: without their private entries, and
 * with scores out of 10 (with decimals) whatever their own score format.
 * Status lists first; custom lists add only what they alone hold (titles set
 * to "hide from status lists"), as fetchListCollection does.
 */
export async function fetchUserList(
	userId: number,
	type: MediaType,
	{ fresh = false }: { fresh?: boolean } = {}
): Promise<CollectionEntry[]> {
	const data = await cachedQuery<{
		MediaListCollection: {
			lists: Array<{
				isCustomList: boolean;
				entries: Array<Omit<CollectionEntry, 'notes' | 'private'>>;
			}> | null;
		} | null;
	}>(USER_LIST_QUERY, { userId, type }, { authToken: null, ...LIST_CACHE, fresh });
	const seen = new Set<number>();
	const entries: CollectionEntry[] = [];
	const lists = [...(data.MediaListCollection?.lists ?? [])].sort(
		(a, b) => Number(a.isCustomList) - Number(b.isCustomList)
	);
	for (const group of lists) {
		for (const entry of group.entries) {
			if (seen.has(entry.mediaId)) continue;
			seen.add(entry.mediaId);
			entries.push({ ...entry, notes: null, private: false });
		}
	}
	return entries;
}

/**
 * AniList's answer for a user who keeps their list private: the error, or
 * its message (a Resource keeps only the message).
 */
export function isPrivateUser(err: unknown): boolean {
	const message = typeof err === 'string' ? err : isAniListError(err, 'api') ? err.message : '';
	return /private user/i.test(message);
}

/** Follows or unfollows someone; returns whether the viewer now follows them. */
export async function toggleFollow(userId: number): Promise<boolean> {
	const data = await anilistQuery<{ ToggleFollow: { isFollowing: boolean } }>(
		TOGGLE_FOLLOW_MUTATION,
		{ userId }
	);
	clearViewerCache();
	return data.ToggleFollow.isFollowing;
}

/** At most this many pages (×50) per week — a guard, not a real limit (~3 pages in practice). */
const MAX_AIRING_PAGES = 8;

/**
 * Every episode airing between `start` and `end` (unix seconds), soonest
 * first. 18+ titles are left out unless `showAdult`.
 */
export async function fetchAiringWeek(
	start: number,
	end: number,
	{ signedIn, showAdult }: { signedIn: boolean; showAdult: boolean }
): Promise<AiringSlot[]> {
	const slots: AiringSlot[] = [];
	for (let page = 1; page <= MAX_AIRING_PAGES; page++) {
		const data = await cachedQuery<AiringWeekResponse>(
			AIRING_WEEK_QUERY,
			{ start, end, page },
			signedIn ? {} : { authToken: null }
		);
		slots.push(...data.Page.airingSchedules);
		if (!data.Page.pageInfo.hasNextPage) break;
	}
	return showAdult ? slots : slots.filter((s) => !s.media.isAdult);
}

/** Popular manga that started serializing since `since` (a Date) and are still running. */
export async function fetchNewManga(
	since: Date,
	{ signedIn, showAdult }: { signedIn: boolean; showAdult: boolean }
): Promise<AniListMedia[]> {
	const fuzzy = since.getFullYear() * 10000 + (since.getMonth() + 1) * 100;
	const data = await cachedQuery<{ Page: { media: AniListMedia[] } }>(
		NEW_MANGA_QUERY,
		{ since: fuzzy, perPage: 24, ...(showAdult ? {} : { isAdult: false }) },
		signedIn ? {} : { authToken: null }
	);
	return data.Page.media;
}

/** The viewer's list entries for these titles (those not on the list are left out). */
export async function fetchListEntries(
	userId: number,
	mediaIds: number[]
): Promise<ListEntriesResponse['Page']['mediaList']> {
	if (!mediaIds.length) return [];
	const data = await cachedQuery<ListEntriesResponse>(LIST_ENTRIES_QUERY, {
		userId,
		ids: mediaIds,
		perPage: Math.min(50, mediaIds.length)
	});
	return data.Page.mediaList;
}

/** All genres and tags, for the filter rail. Public and rarely changing: cached for a day. */
export async function fetchBrowseCollections(): Promise<BrowseCollectionsResponse> {
	return cachedQuery<BrowseCollectionsResponse>(
		BROWSE_COLLECTIONS_QUERY,
		{},
		{ authToken: null, ttl: 24 * 60 * 60 * 1000 }
	);
}

/** Public trending titles for the logged-out Home — no auth token sent. */
export async function fetchPublicTrending(type: MediaType): Promise<AniListMedia[]> {
	const data = await cachedQuery<PublicTrendingResponse>(
		PUBLIC_TRENDING_QUERY,
		{ type, perPage: 16 },
		{ authToken: null }
	);
	return data.trending.media;
}

/** The viewer's daily list activity (about six months), for the Stats heatmap. */
export async function fetchActivityHistory(userId: number): Promise<ActivityDay[]> {
	const data = await cachedQuery<ActivityHistoryResponse>(ACTIVITY_HISTORY_QUERY, { userId });
	return data.User?.stats?.activityHistory ?? [];
}

/** A guard on paging (a season is ~2 pages of 50; a week of airings ~3). */
const MAX_SEASON_PAGES = 6;

const SEASON_START_MONTH: Record<MediaSeason, number> = {
	WINTER: 0,
	SPRING: 3,
	SUMMER: 6,
	FALL: 9
};

/**
 * A season's chart: everything premiering in it, and the "leftovers" — shows
 * from earlier seasons still airing in its second week. 18+ titles are left
 * out unless `showAdult`.
 */
export async function fetchSeasonChart(
	season: MediaSeason,
	year: number,
	{ signedIn, showAdult }: { signedIn: boolean; showAdult: boolean }
): Promise<{ media: SeasonMedia[]; leftovers: SeasonMedia[] }> {
	const auth = signedIn ? {} : { authToken: null };

	const media: SeasonMedia[] = [];
	for (let page = 1; page <= MAX_SEASON_PAGES; page++) {
		const data = await cachedQuery<SeasonChartResponse>(
			SEASON_CHART_QUERY,
			{ season, year, page, ...(showAdult ? {} : { isAdult: false }) },
			auth
		);
		media.push(...data.Page.media);
		if (!data.Page.pageInfo.hasNextPage) break;
	}

	const seasonStart = new Date(year, SEASON_START_MONTH[season], 1);
	const start = Math.floor(seasonStart.getTime() / 1000) + 7 * 86400;
	const end = start + 7 * 86400;
	const inSeason = new Set(media.map((m) => m.id));
	const startKey = year * 100 + SEASON_START_MONTH[season] + 1;
	const leftovers = new Map<number, SeasonMedia>();
	for (let page = 1; page <= MAX_SEASON_PAGES; page++) {
		const data = await cachedQuery<SeasonLeftoversResponse>(
			SEASON_LEFTOVERS_QUERY,
			{ start, end, page },
			auth
		);
		for (const { media: m } of data.Page.airingSchedules) {
			const started = (m.startDate.year ?? 0) * 100 + (m.startDate.month ?? 0);
			if (inSeason.has(m.id) || leftovers.has(m.id) || !started || started >= startKey) continue;
			if (m.isAdult && !showAdult) continue;
			leftovers.set(m.id, m);
		}
		if (!data.Page.pageInfo.hasNextPage) break;
	}
	return { media, leftovers: [...leftovers.values()] };
}
