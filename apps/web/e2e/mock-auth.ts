import type { Page } from '@playwright/test';

interface MockMediaOptions {
	id: number;
	/** The viewer's preferred (userPreferred) title. */
	title: string;
	/** Defaults to `title`; set it to tell the title variants apart. */
	english?: string;
	romaji?: string;
	type?: 'ANIME' | 'MANGA';
	episodes?: number;
	color?: string;
	status?: string;
}

function mockMedia({
	id,
	title,
	english = title,
	romaji = title,
	type = 'ANIME',
	episodes = 24,
	color = '#4fae8a',
	status = 'RELEASING'
}: MockMediaOptions) {
	return {
		id,
		type,
		format: type === 'ANIME' ? 'TV' : 'MANGA',
		status,
		season: 'FALL',
		seasonYear: 2026,
		episodes: type === 'ANIME' ? episodes : null,
		duration: 24,
		chapters: type === 'MANGA' ? episodes : null,
		volumes: null,
		averageScore: 85,
		popularity: 1000,
		favourites: 100,
		isAdult: false,
		title: { romaji, english, native: title, userPreferred: title },
		description: `Mock synopsis for ${title}.`,
		genres: ['Action', 'Fantasy'],
		coverImage: { extraLarge: null, large: null, medium: null, color },
		bannerImage: null,
		studios: { nodes: [{ id: 1, name: 'Mock Studio', siteUrl: null }] },
		nextAiringEpisode: { episode: episodes + 1, airingAt: 0, timeUntilAiring: 86400 }
	};
}

const CONTINUE_MEDIA = mockMedia({
	id: 200001,
	title: 'Mock Continue Anime',
	english: 'Mock Continue English',
	romaji: 'Mock Continue Romaji',
	color: '#d9a75e'
});
const TRENDING_MEDIA = [
	mockMedia({ id: 200002, title: 'Mock Trending One', color: '#e5487a' }),
	mockMedia({ id: 200003, title: 'Mock Trending Two', color: '#3a8fd6' })
];
const POPULAR_MEDIA = [mockMedia({ id: 200004, title: 'Mock Popular One', color: '#6a6fe8' })];
const UPCOMING_MEDIA = [
	mockMedia({
		id: 200005,
		title: 'Mock Upcoming One',
		color: '#c98a4b',
		status: 'NOT_YET_RELEASED'
	})
];
const PUBLIC_TRENDING_MEDIA = [
	mockMedia({
		id: 200006,
		title: 'Mock Public Preferred',
		english: 'Mock Public Trending One',
		romaji: 'Mock Public Romaji',
		color: '#f2c94c'
	})
];

export interface MockListOptions {
	/** Progress on the one continue-list entry; 0 entries = empty list. */
	progress?: number;
	entries?: 0 | 1;
	/** Something is on the list even with nothing in progress. */
	anyEntry?: boolean;
	/** Extra in-progress titles after the first ("Mock Continue 2", "Mock Continue 3", …). */
	extra?: number;
	/** Planning titles for Up next ("Mock Up Next 1", …), 12 episodes each. */
	upNext?: number;
	/** The viewer's unread notifications (the bell's dot). */
	unreadNotifications?: number;
}

/** Re-types the mock media, so manga-mode queries get manga back. */
function asType<T extends { type: string; format: string }>(media: T, type: unknown): T {
	return type === 'MANGA' ? { ...media, type: 'MANGA', format: 'MANGA' } : media;
}

function retyped<T>(data: T, type: unknown): T {
	return JSON.parse(JSON.stringify(data), (key, value) =>
		value && typeof value === 'object' && 'coverImage' in value ? asType(value, type) : value
	);
}

/** HOME_LIST_QUERY: the continue list, and whether the list has anything at all. */
function homeListResponse(
	{ progress = 5, entries = 1, anyEntry = false, extra = 0, upNext = 0 }: MockListOptions = {},
	type?: unknown
) {
	const more = Array.from({ length: extra }, (_, i) => ({
		id: 2 + i,
		progress: 1,
		status: 'CURRENT',
		updatedAt: 0,
		media: mockMedia({ id: 200101 + i, title: `Mock Continue ${i + 2}`, color: '#5ab0ff' })
	}));
	return retyped(
		{
			data: {
				continueList: {
					mediaList: entries
						? [{ id: 1, progress, status: 'CURRENT', updatedAt: 0, media: CONTINUE_MEDIA }, ...more]
						: []
				},
				anyEntry: { mediaList: entries || anyEntry ? [{ id: 1 }] : [] },
				upNext: {
					mediaList: Array.from({ length: upNext }, (_, i) => ({
						id: 900 + i,
						progress: 0,
						status: 'PLANNING',
						updatedAt: 0,
						media: mockMedia({
							id: 200901 + i,
							title: `Mock Up Next ${i + 1}`,
							episodes: 12,
							status: 'FINISHED'
						})
					}))
				}
			}
		},
		type
	);
}

/** HOME_FEED_QUERY: the discovery rows; none of them are on the list. */
function homeFeedResponse(type?: unknown) {
	const own = <T>(media: T[]) => media.map((m) => ({ ...m, mediaListEntry: null }));
	return retyped(
		{
			data: {
				trending: { media: own(TRENDING_MEDIA) },
				popularThisSeason: { media: own(POPULAR_MEDIA) },
				upcoming: { media: own(UPCOMING_MEDIA) }
			}
		},
		type
	);
}

function viewerCountsResponse() {
	return {
		data: { Viewer: { id: 1, statistics: { anime: { count: 167 }, manga: { count: 97 } } } }
	};
}

/** The mock account's settings: AniList's defaults, then every UpdateSettings so far. */
interface AccountSettings {
	titleLanguage: string;
	displayAdultContent: boolean;
	airingNotifications: boolean;
	scoreFormat: string;
}

function accountSettings(calls: AniListCall[]): AccountSettings {
	const settings: AccountSettings = {
		titleLanguage: 'ROMAJI',
		displayAdultContent: false,
		airingNotifications: true,
		scoreFormat: 'POINT_10_DECIMAL'
	};
	for (const c of calls) {
		if (!c.query.includes('mutation UpdateSettings')) continue;
		for (const [key, value] of Object.entries(c.variables)) {
			if (value !== undefined && key in settings) Object.assign(settings, { [key]: value });
		}
	}
	return settings;
}

/** An UpdateSettings result, the way AniList returns it: every setting, saved or not. */
function updateSettingsResponse({ scoreFormat, ...options }: AccountSettings) {
	return { data: { UpdateUser: { id: 1, options, mediaListOptions: { scoreFormat } } } };
}

/** Routes a signed-in request to the matching mock response. */
function signedInResponse(
	query: string,
	variables: Variables,
	name: string,
	list: MockListOptions,
	settings: AccountSettings
) {
	if (query.includes('query HomeList')) return homeListResponse(list, variables.type);
	if (query.includes('query HomeFeed')) return homeFeedResponse(variables.type);
	if (query.includes('query ViewerCounts')) return viewerCountsResponse();
	if (
		query.includes('query UserProfile') &&
		String(variables.name).toLowerCase() === name.toLowerCase()
	)
		return ownProfileResponse(name);
	if (query.includes('query FavouriteMedia')) return favouriteMediaResponse(variables);
	// an empty list unless a test mocks one (mockListCollection)
	if (query.includes('query ListCollection'))
		return { data: { MediaListCollection: { lists: [] } } };
	if (query.includes('mutation UpdateSettings')) return updateSettingsResponse(settings);
	if (query.includes('mutation DeleteEntry'))
		return { data: { DeleteMediaListEntry: { deleted: true } } };
	return viewerQueryResponse(name, settings, list.unreadNotifications);
}

/** Your own page (/user/<you>): member since, and a few favourites. */
function ownProfileResponse(name: string) {
	const person = (id: number, name: string) => ({
		id,
		name: { userPreferred: name },
		image: { large: '', medium: '' },
		siteUrl: `https://anilist.co/character/${id}`
	});
	return {
		data: {
			User: {
				id: 1,
				name,
				about: null,
				avatar: { large: null },
				bannerImage: null,
				isFollowing: false,
				isFollower: false,
				statistics: {
					anime: { count: 4, episodesWatched: 40, minutesWatched: 960, meanScore: 88 },
					manga: { count: 0, chaptersRead: 0, volumesRead: 0, meanScore: 0 }
				},
				createdAt: Date.UTC(2019, 2, 14) / 1000,
				siteUrl: `https://anilist.co/user/${name}`,
				favourites: {
					anime: { nodes: [{ id: 500001 }] },
					manga: { nodes: [{ id: 500002 }] },
					characters: { nodes: [person(500003, 'Favourite Character')] },
					staff: { nodes: [] },
					studios: { nodes: [{ id: 7, name: 'Madhouse', siteUrl: 'https://anilist.co/studio/7' }] }
				}
			}
		}
	};
}

/** Favourite titles by id, as FAVOURITE_MEDIA_QUERY asks for them. */
function favouriteMediaResponse(variables: Variables) {
	const all = [
		// on the viewer's list, so the card shows its status
		{
			...mockMedia({ id: 500001, title: 'Favourite Anime' }),
			mediaListEntry: { id: 900500, status: 'CURRENT', progress: 3 }
		},
		mockMedia({ id: 500002, title: 'Favourite Manga', type: 'MANGA' })
	];
	const ids = (variables.ids as number[] | undefined) ?? [];
	return { data: { Page: { media: all.filter((m) => ids.includes(m.id)) } } };
}

function viewerQueryResponse(
	viewerName: string,
	{ scoreFormat, ...options }: AccountSettings,
	unreadNotificationCount = 0
) {
	return {
		data: {
			Viewer: {
				id: 1,
				name: viewerName,
				avatar: { large: '', medium: '' },
				bannerImage: null,
				unreadNotificationCount,
				mediaListOptions: { scoreFormat },
				options
			}
		}
	};
}

function publicTrendingResponse() {
	return { data: { trending: { media: PUBLIC_TRENDING_MEDIA } } };
}

type Variables = Record<string, unknown>;

/**
 * Each page's list entries as AniList holds them, by media id: seeded by
 * mockListCollection and updated by every save, so a save that sends only
 * some fields gets the rest back unchanged, as from AniList.
 */
const savedEntries = new WeakMap<Page, Map<number, Variables>>();

function entriesOf(page: Page): Map<number, Variables> {
	let entries = savedEntries.get(page);
	if (!entries) savedEntries.set(page, (entries = new Map()));
	return entries;
}

/** Echoes a SaveEntry mutation back the way AniList would: the whole entry. */
function saveEntryResponse(page: Page, variables: Variables) {
	const empty = { year: null, month: null, day: null };
	const mediaId = Number(variables.mediaId);
	const entries = entriesOf(page);
	const sent = Object.fromEntries(Object.entries(variables).filter(([, v]) => v !== undefined));
	const entry: Variables = {
		id: 900000 + mediaId,
		status: 'CURRENT',
		progress: 0,
		progressVolumes: null,
		score: 0,
		repeat: 0,
		notes: null,
		private: false,
		startedAt: empty,
		completedAt: empty,
		...entries.get(mediaId),
		...sent,
		mediaId
	};
	entries.set(mediaId, entry);
	return { data: { SaveMediaListEntry: entry } };
}

export interface AniListCall {
	query: string;
	variables: Variables;
}

async function routeAniList(page: Page, pick: (query: string, variables: Variables) => object) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const variables = body.variables ?? {};
		calls.push({ query: body.query, variables });
		await route.fulfill({
			status: 200,
			contentType: 'application/json',
			body: JSON.stringify(
				body.query.includes('mutation SaveEntry')
					? saveEntryResponse(page, variables)
					: pick(body.query, variables)
			)
		});
	});
	return calls;
}

/**
 * Seeds a fake AniList token and intercepts the real AniList GraphQL API so
 * `session.svelte.ts` and Home's live fetch both resolve with fake data
 * without hitting the network. Call before `page.goto(...)`. Resolves to the
 * list of requests made, for asserting on saves.
 */
export async function mockLoggedIn(page: Page, name = 'haruka_k', list: MockListOptions = {}) {
	const calls: AniListCall[] = await routeAniList(page, (query, variables) =>
		// once something has been saved, the list is no longer empty
		signedInResponse(
			query,
			variables,
			name,
			{
				...list,
				anyEntry: list.anyEntry || calls.some((c) => c.query.includes('mutation SaveEntry'))
			},
			accountSettings(calls)
		)
	);
	await page.addInitScript(() => {
		localStorage.setItem('anilist_token', 'test-token');
	});
	return calls;
}

/** Same as mockLoggedIn but the viewer's AniList list is empty. */
export async function mockLoggedInEmpty(page: Page, name = 'haruka_k') {
	return mockLoggedIn(page, name, { entries: 0 });
}

/**
 * Signed in, but AniList answers the first `failures` requests for one Home
 * section (`query HomeList` or `query HomeFeed`) with a 429.
 */
export async function mockRateLimitedHome(
	page: Page,
	failures = 1,
	retryAfter = 2,
	section: 'HomeList' | 'HomeFeed' = 'HomeList',
	list: MockListOptions = {}
) {
	let remaining = failures;
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		if (body.query.includes(`query ${section}`) && remaining > 0) {
			remaining--;
			await route.fulfill({
				status: 429,
				contentType: 'application/json',
				headers: {
					'Retry-After': String(retryAfter),
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Expose-Headers': 'Retry-After'
				},
				body: JSON.stringify({ errors: [{ message: 'Too Many Requests.', status: 429 }] })
			});
			return;
		}
		await route.fulfill({
			status: 200,
			contentType: 'application/json',
			body: JSON.stringify(
				signedInResponse(body.query, body.variables ?? {}, 'haruka_k', list, accountSettings([]))
			)
		});
	});
	await page.addInitScript(() => {
		localStorage.setItem('anilist_token', 'test-token');
	});
}

/** A stored token that AniList no longer accepts. */
export async function mockExpiredToken(page: Page) {
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string };
		if (body.query.includes('query PublicTrending')) {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(publicTrendingResponse())
			});
			return;
		}
		await route.fulfill({
			status: 400,
			contentType: 'application/json',
			body: JSON.stringify({ errors: [{ message: 'Invalid token', status: 400 }] })
		});
	});
	await page.addInitScript(() => {
		if (!sessionStorage.getItem('seeded')) {
			sessionStorage.setItem('seeded', '1');
			localStorage.setItem('anilist_token', 'expired-token');
		}
	});
}

/** Mocks the public (no-auth) trending query the logged-out Home uses. */
/** A 1×1 PNG, for covers that need to load. */
const TINY_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
	'base64'
);

/**
 * Signed out, Home's feed. With `covers`, the trending titles have cover
 * images (served as a tiny PNG), so their <img> elements render.
 */
export async function mockPublicTrending(page: Page, { covers = false } = {}) {
	if (covers) {
		await page.route('https://s4.anilist.co/**', (route) =>
			route.fulfill({ status: 200, contentType: 'image/png', body: TINY_PNG })
		);
	}
	// signed out, Home also loads the (public) feed rows
	await routeAniList(page, (query, variables) => {
		if (!query.includes('query HomeFeed')) return publicTrendingResponse();
		// trending titles with distinct English / preferred names, to check
		// which one is shown
		const feed = homeFeedResponse(variables.type);
		feed.data.trending.media = retyped(
			PUBLIC_TRENDING_MEDIA.map((m) => ({
				...m,
				mediaListEntry: null,
				...(covers && {
					coverImage: {
						...m.coverImage,
						large: `https://s4.anilist.co/file/test/${m.id}.png`,
						extraLarge: `https://s4.anilist.co/file/test/${m.id}.png`
					}
				})
			})),
			variables.type
		);
		return feed;
	});
}

// ── Browse ──

const BROWSE_GENRES = ['Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Romance'];
const BROWSE_TAGS = [
	{ name: 'Elf', category: 'Cast-Traits', isAdult: false },
	{ name: 'Female Protagonist', category: 'Cast-Main Cast', isAdult: false },
	{ name: 'Time Skip', category: 'Setting-Time', isAdult: false }
];

/** 36 titles (so there's a second page at 30 per page), plus Frieren for search tests. */
function browseCatalog(type: unknown) {
	const titles = Array.from({ length: 35 }, (_, i) => ({
		...mockMedia({ id: 300001 + i, title: `Mock Browse ${i + 1}`, color: '#6a6fe8' }),
		genres: [BROWSE_GENRES[i % BROWSE_GENRES.length]],
		averageScore: 60 + (i % 40),
		mediaListEntry: null
	}));
	const frieren = {
		...mockMedia({
			id: 300100,
			title: 'Sousou no Frieren',
			english: "Frieren: Beyond Journey's End",
			romaji: 'Sousou no Frieren',
			color: '#d9a75e'
		}),
		genres: ['Adventure', 'Drama', 'Fantasy'],
		averageScore: 91,
		mediaListEntry: null
	};
	return retyped([frieren, ...titles], type);
}

type MockBrowseMedia = ReturnType<typeof browseCatalog>[number];

/** A tiny stand-in for AniList's search: enough filtering to test the page's requests. */
function browseResponse(v: Variables) {
	let results: MockBrowseMedia[] = browseCatalog(v.type);
	const search = typeof v.search === 'string' ? v.search.toLowerCase() : '';
	if (search) {
		results = results.filter((m) =>
			[m.title.english, m.title.romaji].some((t) => t?.toLowerCase().includes(search))
		);
	}
	if (Array.isArray(v.genres)) {
		const genres = v.genres as string[];
		results = results.filter((m) => genres.every((g) => m.genres.includes(g)));
	}
	if (Array.isArray(v.formats)) {
		const formats = v.formats as string[];
		results = results.filter((m) => formats.includes(m.format));
	}
	if (typeof v.scoreAbove === 'number') {
		const above = v.scoreAbove;
		results = results.filter((m) => m.averageScore > above);
	}
	if (Array.isArray(v.sort) && v.sort[0] === 'SCORE_DESC') {
		results = [...results].sort((a, b) => b.averageScore - a.averageScore);
	}
	const page = Number(v.page ?? 1);
	const perPage = Number(v.perPage ?? 30);
	const slice = results.slice((page - 1) * perPage, page * perPage);
	const hasNextPage = page * perPage < results.length;
	return {
		data: {
			Page: {
				// like AniList: the total is a placeholder until the last page
				pageInfo: { total: hasNextPage ? 5000 : results.length, currentPage: page, hasNextPage },
				media: slice
			}
		}
	};
}

/**
 * What the real AniList rejects on BROWSE_QUERY (found the hard way): asking
 * for mediaListEntry, `format_in: null` (500) and a null score bound (400).
 */
function browseRejection(query: string, v: Variables): { status: number; message: string } | null {
	if (query.includes('mediaListEntry')) return { status: 500, message: 'Internal Server Error' };
	if ('formats' in v && v.formats === null)
		return { status: 500, message: 'Internal Server Error' };
	if (
		('scoreAbove' in v && v.scoreAbove === null) ||
		('scoreBelow' in v && v.scoreBelow === null)
	) {
		return { status: 400, message: 'Illegal operator and value combination.' };
	}
	return null;
}

/**
 * Mocks Browse's AniList requests (search results, genres and tags). Other
 * requests fall through to any earlier mock (e.g. mockLoggedIn). Resolves to
 * the Browse requests made, for asserting on variables.
 */
export async function mockBrowse(
	page: Page,
	{ onList = {} }: { onList?: Record<number, string> } = {}
) {
	const calls: Variables[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		if (body.query.includes('query BrowseCollections')) {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify({
					data: { GenreCollection: BROWSE_GENRES, MediaTagCollection: BROWSE_TAGS }
				})
			});
			return;
		}
		if (body.query.includes('query Browse(')) {
			const variables = body.variables ?? {};
			calls.push(variables);
			const rejection = browseRejection(body.query, variables);
			await route.fulfill({
				status: rejection?.status ?? 200,
				contentType: 'application/json',
				body: JSON.stringify(
					rejection
						? { errors: [{ message: rejection.message, status: rejection.status }], data: null }
						: browseResponse(variables)
				)
			});
			return;
		}
		if (body.query.includes('query ListEntries')) {
			// the viewer's entries for the titles asked about (signed in only)
			const ids = (body.variables?.ids as number[]) ?? [];
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify({
					data: {
						Page: {
							mediaList: ids
								.filter((id) => onList[id])
								.map((id) => ({ id: id * 10, mediaId: id, status: onList[id], progress: 0 }))
						}
					}
				})
			});
			return;
		}
		if (body.query.includes('query SearchPeople')) {
			// "frieren" matches a character, a voice actor, a user and a studio; anything else, nobody
			const hit = String(body.variables?.search ?? '').toLowerCase() === 'frieren';
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify({
					data: {
						characters: {
							characters: hit
								? [
										{
											id: 176754,
											name: { userPreferred: 'Frieren' },
											image: null,
											media: {
												nodes: [
													{
														title: {
															userPreferred: 'Sousou no Frieren',
															english: "Frieren: Beyond Journey's End",
															romaji: 'Sousou no Frieren'
														}
													}
												]
											}
										}
									]
								: []
						},
						staff: {
							staff: hit
								? [
										{
											id: 95185,
											name: { userPreferred: 'Atsumi Tanezaki' },
											image: null,
											primaryOccupations: ['Voice Actor']
										}
									]
								: []
						},
						users: {
							users: hit
								? [{ id: 5001, name: 'frieren fan', avatar: { large: null, medium: null } }]
								: []
						},
						studios: {
							studios: hit
								? [
										{
											id: 11,
											name: 'MADHOUSE',
											siteUrl: 'https://anilist.co/studio/11',
											isAnimationStudio: true
										}
									]
								: []
						}
					}
				})
			});
			return;
		}
		await route.fallback();
	});
	return calls;
}

// ── Title detail ──

export interface MockEntry {
	status: string;
	progress: number;
	score?: number;
	notes?: string | null;
	startedAt?: { year: number | null; month: number | null; day: number | null };
	/** Each custom list and whether the entry is on it. */
	customLists?: Array<{ name: string; enabled: boolean }>;
}

const EMPTY_DATE = { year: null, month: null, day: null };

function savedEntry(mediaId: number, e: MockEntry) {
	return {
		id: mediaId * 10,
		mediaId,
		status: e.status,
		progress: e.progress,
		progressVolumes: null,
		score: e.score ?? 0,
		repeat: 0,
		notes: e.notes ?? null,
		private: false,
		customLists: e.customLists ?? null,
		startedAt: e.startedAt ?? EMPTY_DATE,
		completedAt: EMPTY_DATE
	};
}

/** A full DETAIL_QUERY response for `id`, in the style of the other mocks. */
function detailResponse(
	id: number,
	{ entry, type = 'ANIME' }: { entry?: MockEntry; type?: 'ANIME' | 'MANGA' }
) {
	const base = mockMedia({
		id,
		title: id === 300100 ? 'Sousou no Frieren' : `Mock Title ${id}`,
		english: id === 300100 ? "Frieren: Beyond Journey's End" : undefined,
		type,
		episodes: 28,
		color: '#d9a75e'
	});
	const person = (pid: number, full: string) => ({
		id: pid,
		name: { full },
		image: { medium: null }
	});
	return {
		data: {
			Media: {
				...base,
				// airs in a day: the countdown shows
				nextAiringEpisode: {
					episode: 9,
					airingAt: Math.floor(Date.now() / 1000) + 86400 + 3600,
					timeUntilAiring: 86400 + 3600
				},
				popularity: 912345,
				source: 'MANGA',
				synonyms: ['Frieren at the Funeral'],
				isFavourite: false,
				tags: [
					{
						id: 1,
						name: 'Travel',
						rank: 96,
						description: 'Journeys.',
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 2,
						name: 'Time Skip',
						rank: 82,
						description: null,
						isMediaSpoiler: true,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 10,
						name: 'Magic',
						rank: 80,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 11,
						name: 'Elf',
						rank: 75,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 12,
						name: 'Female Protagonist',
						rank: 70,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 13,
						name: 'Medieval',
						rank: 65,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 14,
						name: 'Iyashikei',
						rank: 60,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 15,
						name: 'Episodic',
						rank: 55,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 16,
						name: 'Demons',
						rank: 50,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 17,
						name: 'Coming of Age',
						rank: 45,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					},
					{
						id: 18,
						name: 'Philosophy',
						rank: 40,
						description: null,
						isMediaSpoiler: false,
						isGeneralSpoiler: false,
						isAdult: false
					}
				],
				externalLinks: [
					{
						id: 1,
						url: 'https://www.crunchyroll.com/series/mock',
						site: 'Crunchyroll',
						type: 'STREAMING',
						language: null,
						color: '#F88B24',
						icon: null,
						notes: null,
						isDisabled: false
					},
					{
						id: 2,
						url: 'https://example.com/official',
						site: 'Official Site',
						type: 'INFO',
						language: 'Japanese',
						color: null,
						icon: null,
						notes: null,
						isDisabled: false
					}
				],
				startDate: { year: 2026, month: 10, day: 2 },
				endDate: EMPTY_DATE,
				rankings: [{ rank: 2, type: 'RATED', allTime: true, context: 'highest rated all time' }],
				trailer: { id: 'abc123', site: 'youtube', thumbnail: null },
				staff: { edges: [{ role: 'Story & Art', node: person(1, 'Mock Author') }] },
				characters: {
					edges: [
						{
							role: 'MAIN',
							node: person(11, 'Mock Hero'),
							voiceActors: [person(21, 'Mock Voice')]
						},
						{ role: 'SUPPORTING', node: person(12, 'Mock Friend'), voiceActors: [] }
					]
				},
				relations: {
					edges: [
						{
							relationType: 'SEQUEL',
							node: {
								id: 300200,
								type: 'ANIME',
								format: 'TV',
								status: 'NOT_YET_RELEASED',
								episodes: null,
								chapters: null,
								seasonYear: 2027,
								title: {
									romaji: 'Mock Sequel',
									english: 'Mock Sequel',
									userPreferred: 'Mock Sequel'
								},
								coverImage: { large: null, color: '#3a8fd6' }
							}
						}
					]
				},
				recommendations: {
					nodes: [{ mediaRecommendation: mockMedia({ id: 300300, title: 'Mock Recommendation' }) }]
				},
				mediaListEntry: entry ? savedEntry(id, entry) : null
			}
		}
	};
}

function titleStatsResponse(id: number) {
	const ranking = (id: number, rank: number, type: string, more: object) => ({
		id,
		rank,
		type,
		format: 'TV',
		year: null,
		season: null,
		allTime: false,
		context: '',
		...more
	});
	return {
		data: {
			Media: {
				id,
				averageScore: 88,
				favourites: 4_200,
				stats: {
					scoreDistribution: [
						{ score: 100, amount: 6_000 },
						{ score: 90, amount: 3_000 },
						{ score: 50, amount: 200 }
					],
					statusDistribution: [
						{ status: 'CURRENT', amount: 2_000 },
						{ status: 'COMPLETED', amount: 5_000 },
						{ status: 'DROPPED', amount: 500 },
						{ status: 'PLANNING', amount: 2_500 }
					]
				},
				rankings: [
					ranking(2, 3, 'RATED', { season: 'FALL', year: 2023 }),
					ranking(1, 12, 'RATED', { allTime: true })
				]
			}
		}
	};
}

/**
 * Mocks the title page's AniList requests: the detail query, the Stats tab,
 * the editor's entry query and favourites. Other requests fall through to earlier mocks.
 * `entry` is the viewer's list entry for every title asked about.
 */
export async function mockDetail(
	page: Page,
	{
		entry,
		type = 'ANIME',
		onList = {}
	}: {
		entry?: MockEntry;
		type?: 'ANIME' | 'MANGA';
		/** Other titles on the viewer's list (e.g. a recommendation), by media id. */
		onList?: Record<number, string>;
	} = {}
) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const variables = body.variables ?? {};
		const json = (data: unknown, status = 200) =>
			route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) });
		if (body.query.includes('query Detail')) {
			calls.push({ query: body.query, variables });
			return json(detailResponse(Number(variables.id), { entry, type }));
		}
		if (body.query.includes('query TitleStats')) {
			calls.push({ query: body.query, variables });
			return json(titleStatsResponse(Number(variables.id)));
		}
		if (body.query.includes('query Entry')) {
			calls.push({ query: body.query, variables });
			return entry
				? json({ data: { MediaList: savedEntry(Number(variables.mediaId), entry) } })
				: json(
						{ errors: [{ message: 'Not Found.', status: 404 }], data: { MediaList: null } },
						404
					);
		}
		if (body.query.includes('query ListEntries')) {
			calls.push({ query: body.query, variables });
			const ids = (variables.ids as number[]) ?? [];
			return json({
				data: {
					Page: {
						mediaList: ids
							.filter((id) => onList[id])
							.map((id) => ({ id: id * 10, mediaId: id, status: onList[id], progress: 3 }))
					}
				}
			});
		}
		if (body.query.includes('mutation ToggleFavourite')) {
			calls.push({ query: body.query, variables });
			return json({ data: { ToggleFavourite: { anime: { pageInfo: { total: 1 } } } } });
		}
		await route.fallback();
	});
	return calls;
}

// ── My List ──

export interface MockListEntry {
	id: number;
	title: string;
	status: string;
	progress: number;
	score?: number;
	episodes?: number;
	format?: string;
	/** Seconds from now until the next episode airs. */
	airsIn?: number;
	nextEpisode?: number;
	/** Seconds ago it was last updated. */
	updatedAgo?: number;
	/** The custom lists it's on. */
	lists?: string[];
	/** "Hide from status lists": on its custom lists only. */
	hidden?: boolean;
}

/** A MediaListCollection response grouped by status, like AniList's. */
// ── People: staff and character pages ──

function personMedia(id: number, title: string, year = 2023, type = 'ANIME') {
	return {
		id,
		type,
		format: type === 'ANIME' ? 'TV' : 'MANGA',
		seasonYear: year,
		startDate: { year },
		title: { romaji: title, english: title, native: null, userPreferred: title },
		coverImage: { large: null, color: '#d9a75e' },
		isAdult: false
	};
}

/** A voice actor's roles: page 1 is popular-first, page 2 (and ?sort=newest) say so in their titles. */
function voiceRolesPage(variables: Variables) {
	const page = Number(variables.page ?? 1);
	const newest = (variables.sort as string[] | undefined)?.[0] === 'START_DATE_DESC';
	const prefix = newest ? 'Newest' : page === 1 ? 'Popular' : 'More';
	return {
		pageInfo: { total: 3, hasNextPage: page === 1 && !newest },
		edges: [
			{
				characterRole: 'MAIN',
				characters: [
					{ id: 400100 + page, name: { full: `${prefix} Hero`, userPreferred: null }, image: null }
				],
				node: personMedia(300100 + page * 10, `${prefix} Show`)
			}
		]
	};
}

function staffResponse(id: number, variables: Variables) {
	return {
		id,
		name: { full: 'Mock Voice', native: 'モック', userPreferred: 'Mock Voice', alternative: [] },
		image: { large: null },
		description: '__Height:__ 157 cm\n\nA voice actress. ~!Secret twist.!~',
		primaryOccupations: ['Voice Actor'],
		gender: 'Female',
		languageV2: 'Japanese',
		dateOfBirth: { year: 1990, month: 9, day: 27 },
		dateOfDeath: EMPTY_DATE,
		age: 36,
		yearsActive: [2008],
		homeTown: null,
		bloodType: null,
		favourites: 3922,
		isFavourite: false,
		siteUrl: `https://anilist.co/staff/${id}`,
		characterMedia: voiceRolesPage(variables),
		staffMedia: {
			pageInfo: { total: 1, hasNextPage: false },
			edges: [{ staffRole: 'Theme Song Performance', node: personMedia(300300, 'Sung Show') }]
		}
	};
}

function characterResponse(id: number) {
	const va = (vid: number, full: string, languageV2: string) => ({
		roleNotes: null,
		voiceActor: { id: vid, name: { full, userPreferred: null }, image: null, languageV2 }
	});
	return {
		id,
		name: {
			full: 'Mock Hero',
			native: 'ヒーロー',
			userPreferred: 'Mock Hero',
			alternative: ['The Hero'],
			alternativeSpoiler: ['Secret Name']
		},
		image: { large: null },
		description: 'The hero of [Mock Title](https://anilist.co/anime/300100).',
		gender: 'Female',
		age: '1000+',
		bloodType: null,
		dateOfBirth: EMPTY_DATE,
		favourites: 22589,
		isFavourite: false,
		siteUrl: `https://anilist.co/character/${id}`,
		media: {
			pageInfo: { total: 1, hasNextPage: false },
			edges: [
				{
					characterRole: 'MAIN',
					voiceActorRoles: [va(21, 'Mock Voice', 'Japanese'), va(22, 'Mock Dub', 'English')],
					node: personMedia(300100, 'Mock Title')
				}
			]
		}
	};
}

/** The staff and character pages; id 999 is one AniList doesn't know. */
/**
 * A studio's titles: page 1 is popular-first with a co-production, page 2
 * (and ?sort=newest) say so in their titles.
 */
function studioMediaPage(variables: Variables) {
	const page = Number(variables.page ?? 1);
	const newest = (variables.sort as string[] | undefined)?.[0] === 'START_DATE_DESC';
	const prefix = newest ? 'Newest' : page === 1 ? 'Popular' : 'More';
	return {
		pageInfo: { total: 3, hasNextPage: page === 1 && !newest },
		edges: [
			{ isMainStudio: true, node: personMedia(300300 + page, `${prefix} Studio Show`) },
			...(page === 1 && !newest
				? [{ isMainStudio: false, node: personMedia(300310, 'Produced Show') }]
				: [])
		]
	};
}

export async function mockPeople(
	page: Page,
	{ onList = {} }: { onList?: Record<number, string> } = {}
) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const variables = body.variables ?? {};
		const json = (data: unknown, status = 200) =>
			route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) });
		const notFound = () =>
			json({ errors: [{ message: 'Not Found.', status: 404 }], data: null }, 404);
		const id = Number(variables.id);
		if (body.query.includes('query StaffPage')) {
			calls.push({ query: body.query, variables });
			return id === 999 ? notFound() : json({ data: { Staff: staffResponse(id, variables) } });
		}
		if (body.query.includes('query StaffVoiceRoles')) {
			calls.push({ query: body.query, variables });
			return json({ data: { Staff: { id, characterMedia: voiceRolesPage(variables) } } });
		}
		if (body.query.includes('query StaffCredits')) {
			calls.push({ query: body.query, variables });
			return json({
				data: { Staff: { id, staffMedia: staffResponse(id, variables).staffMedia } }
			});
		}
		if (body.query.includes('query StudioPage')) {
			calls.push({ query: body.query, variables });
			if (id === 999) return notFound();
			return json({
				data: {
					Studio: {
						id,
						name: 'Mock Studio',
						isAnimationStudio: true,
						siteUrl: `https://anilist.co/studio/${id}`,
						favourites: 20029,
						isFavourite: false,
						media: studioMediaPage(variables)
					}
				}
			});
		}
		if (body.query.includes('query StudioMedia')) {
			calls.push({ query: body.query, variables });
			return json({ data: { Studio: { id, media: studioMediaPage(variables) } } });
		}
		if (body.query.includes('query CharacterPage')) {
			calls.push({ query: body.query, variables });
			return id === 999 ? notFound() : json({ data: { Character: characterResponse(id) } });
		}
		if (body.query.includes('query ListEntries')) {
			calls.push({ query: body.query, variables });
			const ids = (variables.ids as number[]) ?? [];
			return json({
				data: {
					Page: {
						mediaList: ids
							.filter((mid) => onList[mid])
							.map((mid) => ({ id: mid * 10, mediaId: mid, status: onList[mid], progress: 3 }))
					}
				}
			});
		}
		if (body.query.includes('mutation ToggleFavourite')) {
			calls.push({ query: body.query, variables });
			return json({ data: { ToggleFavourite: { anime: { pageInfo: { total: 1 } } } } });
		}
		await route.fallback();
	});
	return calls;
}

// ── Other people's pages (/user/[name]) ──

/** rin: a public profile; hidden: a private list; anyone else isn't on AniList. */
function userProfileResponse(name: string) {
	const person = (id: number, full: string) => ({
		id,
		name: { userPreferred: full },
		image: { large: '', medium: '' },
		siteUrl: `https://anilist.co/character/${id}`
	});
	return {
		data: {
			User: {
				id: name === 'hidden' ? 701 : 700,
				name,
				about: 'I watch __everything__. ~!Even the sequels.!~',
				avatar: { large: null },
				bannerImage: null,
				createdAt: Date.UTC(2016, 4, 2) / 1000,
				siteUrl: `https://anilist.co/user/${name}`,
				isFollowing: false,
				isFollower: true,
				statistics: {
					anime: { count: 3, episodesWatched: 48, minutesWatched: 1152, meanScore: 82 },
					manga: { count: 0, chaptersRead: 0, volumesRead: 0, meanScore: 0 }
				},
				favourites: {
					anime: { nodes: [{ id: 500001 }] },
					manga: { nodes: [] },
					characters: { nodes: [person(500003, 'Their Character')] },
					staff: { nodes: [] },
					studios: { nodes: [] }
				}
			}
		}
	};
}

function userListResponse() {
	const entry = (
		id: number,
		title: string,
		status: string,
		score: number,
		isAdult = false,
		{ genres = ['Action'], countryOfOrigin = 'JP', seasonYear = 2026 } = {}
	) => ({
		id: id * 10,
		mediaId: id,
		status,
		progress: status === 'COMPLETED' ? 12 : 4,
		progressVolumes: null,
		score,
		repeat: 0,
		updatedAt: Math.floor(Date.now() / 1000) - 3600,
		startedAt: EMPTY_DATE,
		completedAt: EMPTY_DATE,
		media: {
			...mockMedia({ id, title, episodes: 12 }),
			duration: 24,
			isAdult,
			genres,
			countryOfOrigin,
			seasonYear,
			startDate: { year: seasonYear }
		}
	});
	return {
		data: {
			MediaListCollection: {
				lists: [
					{
						status: 'COMPLETED',
						isCustomList: false,
						entries: [
							entry(600001, 'Good Show', 'COMPLETED', 7.5, false, {
								genres: ['Drama', 'Romance'],
								countryOfOrigin: 'KR',
								seasonYear: 2019
							}),
							entry(600002, 'Best Show', 'COMPLETED', 9.5)
						]
					},
					{
						status: 'CURRENT',
						isCustomList: false,
						entries: [entry(600003, 'Ongoing Show', 'CURRENT', 0)]
					},
					{
						// 18+: hidden from a viewer whose account doesn't show it, in the list and the totals
						status: 'PAUSED',
						isCustomList: false,
						entries: [entry(600004, 'Grown-up Show', 'PAUSED', 8, true)]
					}
				]
			}
		}
	};
}

/** Someone else's page: their profile, list, activity and following them. */
export async function mockUser(page: Page) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const variables = body.variables ?? {};
		const json = (data: unknown, status = 200) =>
			route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) });
		const fail = (message: string) => json({ errors: [{ message, status: 404 }], data: null }, 404);
		if (body.query.includes('query UserProfile')) {
			calls.push({ query: body.query, variables });
			const name = String(variables.name);
			if (name === 'rin' || name === 'hidden') return json(userProfileResponse(name));
			// anyone else may be the signed-in viewer, answered by mockLoggedIn
			return name === 'nobody' ? fail('Not Found.') : route.fallback();
		}
		if (body.query.includes('query UserList')) {
			calls.push({ query: body.query, variables });
			if (variables.userId === 701) return fail('Private User');
			return json(
				variables.type === 'ANIME'
					? userListResponse()
					: { data: { MediaListCollection: { lists: [] } } }
			);
		}
		if (body.query.includes('query FavouriteMedia')) return json(favouriteMediaResponse(variables));
		if (body.query.includes('query ActivityHistory')) {
			return json({ data: { User: { id: variables.userId, stats: { activityHistory: [] } } } });
		}
		if (body.query.includes('mutation ToggleFollow')) {
			calls.push({ query: body.query, variables });
			return json({ data: { ToggleFollow: { id: variables.userId, isFollowing: true } } });
		}
		await route.fallback();
	});
	return calls;
}

function collectionResponse(entries: MockListEntry[], type: unknown) {
	const now = Math.floor(Date.now() / 1000);
	const byStatus = new Map<string, unknown[]>();
	const custom = new Map<string, unknown[]>();
	for (const e of entries) {
		const media = {
			...mockMedia({ id: e.id, title: e.title, episodes: e.episodes ?? 24, color: '#5ab0ff' }),
			format: e.format ?? 'TV',
			nextAiringEpisode: e.airsIn
				? {
						episode: e.nextEpisode ?? e.progress + 1,
						airingAt: now + e.airsIn,
						timeUntilAiring: e.airsIn
					}
				: null
		};
		const row = {
			...savedEntry(e.id, { status: e.status, progress: e.progress, score: e.score }),
			updatedAt: now - (e.updatedAgo ?? 3600),
			media
		};
		if (!e.hidden) byStatus.set(e.status, [...(byStatus.get(e.status) ?? []), row]);
		for (const name of e.lists ?? []) custom.set(name, [...(custom.get(name) ?? []), row]);
	}
	return retyped(
		{
			data: {
				MediaListCollection: {
					lists: [
						...[...byStatus].map(([status, rows]) => ({
							name: status,
							status,
							isCustomList: false,
							entries: rows
						})),
						...[...custom].map(([name, rows]) => ({
							name,
							status: null,
							isCustomList: true,
							entries: rows
						}))
					]
				}
			}
		},
		type
	);
}

/** Mocks My List's collection query (signed in via mockLoggedIn first). */
export async function mockListCollection(page: Page, entries: MockListEntry[]) {
	const saved = entriesOf(page);
	for (const e of entries) {
		saved.set(e.id, { status: e.status, progress: e.progress, score: e.score ?? 0 });
	}
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		if (body.query.includes('query ListCollection')) {
			calls.push({ query: body.query, variables: body.variables ?? {} });
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(collectionResponse(entries, body.variables?.type))
			});
			return;
		}
		await route.fallback();
	});
	return calls;
}

// ── Seasonal ──

export interface MockAiring {
	id: number;
	mediaId: number;
	title: string;
	episode: number;
	/** Unix seconds. */
	airingAt: number;
	episodes?: number;
}

/**
 * Mocks the week's airings (filtered by the request's start/end, one page),
 * the newly serialized manga query, and the viewer's list entries for the
 * week (`onList`: mediaId → [status, progress]).
 */
export async function mockSeasonal(
	page: Page,
	airings: MockAiring[],
	{ onList = {} }: { onList?: Record<number, [string, number]> } = {}
) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const v = body.variables ?? {};
		const json = (data: unknown) =>
			route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data) });
		if (body.query.includes('query AiringWeek')) {
			calls.push({ query: body.query, variables: v });
			const inWeek = airings.filter(
				(a) => a.airingAt > Number(v.start) && a.airingAt < Number(v.end)
			);
			return json({
				data: {
					Page: {
						pageInfo: { hasNextPage: false },
						airingSchedules: inWeek.map((a) => ({
							id: a.id,
							episode: a.episode,
							airingAt: a.airingAt,
							media: {
								...mockMedia({ id: a.mediaId, title: a.title, episodes: a.episodes ?? 12 }),
								nextAiringEpisode: null
							}
						}))
					}
				}
			});
		}
		if (body.query.includes('query NewManga')) {
			calls.push({ query: body.query, variables: v });
			return json({
				data: {
					Page: {
						media: [
							mockMedia({ id: 500001, title: 'Mock New Manga', type: 'MANGA' }),
							mockMedia({ id: 500002, title: 'Mock Newer Manga', type: 'MANGA' })
						]
					}
				}
			});
		}
		if (body.query.includes('query ListEntries')) {
			const ids = (v.ids as number[]) ?? [];
			return json({
				data: {
					Page: {
						mediaList: ids
							.filter((id) => onList[id])
							.map((id) => ({
								id: id * 10,
								mediaId: id,
								status: onList[id][0],
								progress: onList[id][1]
							}))
					}
				}
			});
		}
		await route.fallback();
	});
	return calls;
}

// ── Season chart ──

export interface MockSeasonTitle {
	id: number;
	title: string;
	format?: string;
	episodes?: number;
	/** Seconds from now until the next episode; none = not airing. */
	airsIn?: number;
	nextEpisode?: number;
	score?: number | null;
	/** This season's popularity rank. */
	rank?: number;
	source?: string;
	sequelTo?: string;
	status?: string;
	genres?: string[];
}

function seasonMedia(t: MockSeasonTitle, season: string, year: number, nowMs: number) {
	const now = Math.floor(nowMs / 1000);
	return {
		...mockMedia({ id: t.id, title: t.title, episodes: t.episodes ?? 12, status: t.status }),
		format: t.format ?? 'TV',
		genres: t.genres ?? ['Action', 'Fantasy'],
		averageScore: t.score === undefined ? 80 : t.score,
		source: t.source ?? 'MANGA',
		startDate: { year, month: 10, day: 3 },
		nextAiringEpisode: t.airsIn
			? { episode: t.nextEpisode ?? 2, airingAt: now + t.airsIn, timeUntilAiring: t.airsIn }
			: null,
		rankings: t.rank ? [{ rank: t.rank, type: 'POPULAR', season, year, allTime: false }] : [],
		relations: {
			edges: t.sequelTo
				? [
						{
							relationType: 'PREQUEL',
							node: {
								id: t.id + 1000,
								type: 'ANIME',
								title: { romaji: t.sequelTo, english: t.sequelTo, userPreferred: t.sequelTo }
							}
						}
					]
				: []
		}
	};
}

/**
 * Mocks the season chart (one page per season) and its leftovers query.
 * `seasons` is keyed "FALL 2026"; leftovers start in an earlier year.
 */
export async function mockSeasonChart(
	page: Page,
	seasons: Record<string, MockSeasonTitle[]>,
	leftovers: MockSeasonTitle[] = [],
	/** What countdowns count from; match the page's (fixed) clock. */
	now = new Date()
) {
	const calls: AniListCall[] = [];
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const body = route.request().postDataJSON() as { query: string; variables?: Variables };
		const v = body.variables ?? {};
		const json = (data: unknown) =>
			route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data) });
		if (body.query.includes('query SeasonChart')) {
			calls.push({ query: body.query, variables: v });
			const titles = seasons[`${v.season} ${v.year}`] ?? [];
			return json({
				data: {
					Page: {
						pageInfo: { hasNextPage: false },
						media: titles.map((t) =>
							seasonMedia(t, String(v.season), Number(v.year), now.getTime())
						)
					}
				}
			});
		}
		if (body.query.includes('query SeasonLeftovers')) {
			return json({
				data: {
					Page: {
						pageInfo: { hasNextPage: false },
						airingSchedules: leftovers.map((t) => ({
							media: {
								...seasonMedia(t, 'SUMMER', 2026, now.getTime()),
								startDate: { year: 2025, month: 7, day: 1 }
							}
						}))
					}
				}
			});
		}
		await route.fallback();
	});
	return calls;
}

// ── For You ──

export interface MockRecommendation {
	id: number;
	title: string;
	/** AniList's vote count for the recommendation. */
	rating: number;
}

/** Answers FOR_YOU queries: each aliased Media(id:) gets the recommendations listed for that seed id. */
/** A seed's related title, for For You's cross-mode picks. */
export interface MockRelation {
	relationType: 'SOURCE' | 'ADAPTATION' | 'SEQUEL';
	id: number;
	title: string;
	type: 'ANIME' | 'MANGA';
	genres?: string[];
}

export async function mockForYou(
	page: Page,
	bySeed: Record<number, MockRecommendation[]>,
	{ relations = {} }: { relations?: Record<number, MockRelation[]> } = {}
) {
	await page.route('https://graphql.anilist.co/**', async (route) => {
		const { query } = route.request().postDataJSON() as { query: string };
		if (query.includes('query ForYouRelations')) {
			const data: Record<string, unknown> = {};
			for (const [, alias, id] of query.matchAll(/(s\d+): Media\(id: (\d+)\)/g)) {
				data[alias] = {
					id: Number(id),
					relations: {
						edges: (relations[Number(id)] ?? []).map((r) => ({
							relationType: r.relationType,
							node: {
								...mockMedia({ id: r.id, title: r.title }),
								type: r.type,
								...(r.genres && { genres: r.genres }),
								mediaListEntry: null
							}
						}))
					}
				};
			}
			return route.fulfill({ json: { data } });
		}
		if (!query.includes('query ForYou')) return route.fallback();
		const data: Record<string, unknown> = {};
		for (const [, alias, id] of query.matchAll(/(s\d+): Media\(id: (\d+)\)/g)) {
			data[alias] = {
				id: Number(id),
				recommendations: {
					nodes: (bySeed[Number(id)] ?? []).map((r) => ({
						rating: r.rating,
						mediaRecommendation: {
							...mockMedia({ id: r.id, title: r.title }),
							mediaListEntry: null
						}
					}))
				}
			};
		}
		await route.fulfill({ json: { data } });
	});
}
