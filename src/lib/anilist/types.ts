// ── Live: wired into the real auth flow (client.ts, session.svelte.ts, Navbar)
// and the Home feed (client.ts fetchHomeList/fetchHomeFeed, adapt.ts, page-data/home.ts) ──

export type MediaType = 'ANIME' | 'MANGA';
export type MediaSeason = 'WINTER' | 'SPRING' | 'SUMMER' | 'FALL';
export type MediaListStatus =
	'CURRENT' | 'PLANNING' | 'COMPLETED' | 'DROPPED' | 'PAUSED' | 'REPEATING';
export type ScoreFormat = 'POINT_100' | 'POINT_10_DECIMAL' | 'POINT_10' | 'POINT_5' | 'POINT_3';
/** AniList's UserTitleLanguage. The _STYLISED variants keep official casing/punctuation. */
export type TitleLanguage =
	'ROMAJI' | 'ENGLISH' | 'NATIVE' | 'ROMAJI_STYLISED' | 'ENGLISH_STYLISED' | 'NATIVE_STYLISED';

export interface AniListAvatar {
	large: string | null;
	medium: string | null;
}

export interface AniListUser {
	id: number;
	name: string;
	avatar: AniListAvatar;
	bannerImage: string | null;
	unreadNotificationCount: number;
	mediaListOptions?: {
		scoreFormat: ScoreFormat;
		/** Every custom list's name, empty ones too. */
		animeList?: { customLists: string[] | null } | null;
		mangaList?: { customLists: string[] | null } | null;
	};
	options?: {
		titleLanguage?: TitleLanguage;
		displayAdultContent: boolean;
		/** AniList notifies you when an episode of something you're watching airs. */
		airingNotifications?: boolean;
	};
}

/** The viewer's own list entry for a title, as HOME_FEED_QUERY attaches it. */
export interface AniListOwnEntry {
	id: number;
	status: MediaListStatus;
	progress: number;
}

export interface AniListMediaTitle {
	romaji: string | null;
	english: string | null;
	native: string | null;
	userPreferred: string | null;
}

export interface AniListCoverImage {
	extraLarge: string | null;
	large: string | null;
	medium: string | null;
	color: string | null;
}

export interface AniListStudio {
	id: number;
	name: string;
	siteUrl: string | null;
}

export interface AniListNextAiringEpisode {
	episode: number;
	airingAt: number;
	timeUntilAiring: number;
}

export interface AniListMedia {
	id: number;
	type: MediaType;
	format: string | null;
	status: string | null;
	season: MediaSeason | null;
	seasonYear: number | null;
	episodes: number | null;
	duration: number | null;
	chapters: number | null;
	volumes: number | null;
	averageScore: number | null;
	popularity: number | null;
	favourites: number | null;
	isAdult: boolean;
	title: AniListMediaTitle;
	description: string | null;
	genres: string[];
	/** "JP", "KR", "CN", "TW"…; on list collection results. */
	countryOfOrigin?: string | null;
	/** Only its year, on list collection results (manga have no seasonYear). */
	startDate?: Pick<AniListDate, 'year'> | null;
	coverImage: AniListCoverImage;
	bannerImage: string | null;
	studios: {
		nodes: AniListStudio[];
	};
	nextAiringEpisode: AniListNextAiringEpisode | null;
	/** Only on HOME_FEED_QUERY results; null when the title isn't on the list. */
	mediaListEntry?: AniListOwnEntry | null;
}

export interface AniListDate {
	year: number | null;
	month: number | null;
	day: number | null;
}

export interface AniListMediaListEntry {
	id: number;
	status: MediaListStatus;
	progress: number;
	updatedAt: number;
	media: AniListMedia;
}

/** The list-entry fields SaveMediaListEntry returns (SAVE_ENTRY_MUTATION). */
export interface AniListSavedEntry {
	id: number;
	mediaId: number;
	status: MediaListStatus;
	progress: number;
	progressVolumes: number | null;
	/** In the viewer's own scoreFormat. */
	score: number;
	repeat: number;
	notes: string | null;
	private: boolean;
	/** Up next order on Planning: higher comes first. */
	priority?: number;
	/** Each custom list of the entry's type and whether it's on it; null with none. */
	customLists?: Array<{ name: string; enabled: boolean }> | null;
	startedAt: AniListDate;
	completedAt: AniListDate;
}

export interface AniListPage<T> {
	media: T[];
}

export interface AniListMediaListPage {
	mediaList: AniListMediaListEntry[];
}

/** Shape returned by HOME_LIST_QUERY — see fetchHomeList() in client.ts. */
export interface HomeListResponse {
	continueList: AniListMediaListPage;
	/** The first few on Planning, in the viewer's priority order: Continue's Up next. */
	upNext?: AniListMediaListPage;
	/** At most one entry of any status: tells an empty list from one with nothing in progress. */
	anyEntry: { mediaList: Array<{ id: number }> };
}

/** Shape returned by HOME_FEED_QUERY — see fetchHomeFeed() in client.ts. */
export interface HomeFeedResponse {
	trending: AniListPage<AniListMedia>;
	popularThisSeason: AniListPage<AniListMedia>;
	upcoming: AniListPage<AniListMedia>;
}

/** Shape returned by BROWSE_QUERY. */
export interface BrowseResponse {
	Page: {
		pageInfo: { total: number; currentPage: number; hasNextPage: boolean };
		media: AniListMedia[];
	};
}

export interface AniListTag {
	name: string;
	category: string;
	isAdult: boolean;
}

// ── A title's Stats tab (client.ts fetchTitleStats) ──

export interface TitleRanking {
	id: number;
	rank: number;
	type: 'RATED' | 'POPULAR';
	format: string;
	year: number | null;
	season: MediaSeason | null;
	allTime: boolean;
	/** "highest rated all time", "most popular". */
	context: string;
}

export interface TitleStatsResponse {
	Media: {
		id: number;
		/** Out of 100. */
		averageScore: number | null;
		favourites: number | null;
		stats: {
			/** Scores 10, 20 … 100. */
			scoreDistribution: Array<{ score: number; amount: number }> | null;
			statusDistribution: Array<{ status: MediaListStatus; amount: number }> | null;
		} | null;
		rankings: TitleRanking[] | null;
	};
}

// ── Title detail (DETAIL_QUERY) ──

export interface AniListPerson {
	id: number;
	name: { full: string };
	image: { medium: string | null } | null;
}

export interface AniListRelation {
	/** e.g. SOURCE, PREQUEL, SEQUEL, ADAPTATION, SIDE_STORY (relationType v2). */
	relationType: string;
	node: {
		id: number;
		type: MediaType;
		format: string | null;
		status: string | null;
		episodes: number | null;
		chapters: number | null;
		seasonYear: number | null;
		/** For ordering relations of the same kind (2nd season before 3rd). */
		startDate?: AniListDate | null;
		title: { romaji: string | null; english: string | null; userPreferred: string | null };
		coverImage: { large: string | null; color: string | null };
	};
}

/** A tag on one title, ranked by how well it fits (0–100). */
export interface AniListMediaTag {
	id: number;
	name: string;
	rank: number;
	description: string | null;
	/** Gives away this title's story. */
	isMediaSpoiler: boolean;
	/** Gives away the story of any title it's on. */
	isGeneralSpoiler: boolean;
	isAdult: boolean;
}

/** A link from a title's page: where to watch or read it, or its official sites. */
export interface AniListExternalLink {
	id: number;
	url: string;
	site: string;
	type: 'STREAMING' | 'INFO' | 'SOCIAL' | null;
	language: string | null;
	color: string | null;
	icon: string | null;
	/** e.g. the uploader, "Muse Asia". */
	notes: string | null;
	isDisabled: boolean | null;
}

export interface DetailMedia extends AniListMedia {
	source: string | null;
	synonyms: string[];
	isFavourite: boolean;
	tags: AniListMediaTag[];
	externalLinks: AniListExternalLink[];
	startDate: AniListDate;
	endDate: AniListDate;
	rankings: Array<{ rank: number; type: 'RATED' | 'POPULAR'; allTime: boolean; context: string }>;
	trailer: { id: string; site: string; thumbnail: string | null } | null;
	staff: { edges: Array<{ role: string; node: AniListPerson }> };
	characters: {
		edges: Array<{ role: string; node: AniListPerson; voiceActors: AniListPerson[] }>;
	};
	relations: { edges: AniListRelation[] };
	recommendations: { nodes: Array<{ mediaRecommendation: AniListMedia | null }> };
	/** The viewer's full entry; null when not on the list or signed out. */
	mediaListEntry: AniListSavedEntry | null;
}

export interface DetailResponse {
	Media: DetailMedia;
}

/** One row of MediaListCollection: the full entry plus its (lighter) media. */
export interface CollectionEntry extends AniListSavedEntry {
	/** Unix seconds. */
	updatedAt: number;
	media: AniListMedia;
}

/** Shape returned by LIST_COLLECTION_QUERY. */
export interface ListCollectionResponse {
	/** Read as an empty list when missing, rather than crash the page asking. */
	MediaListCollection: {
		lists: Array<{
			name: string;
			status: MediaListStatus | null;
			isCustomList: boolean;
			entries: CollectionEntry[];
		}> | null;
	} | null;
}

export interface AiringSlot {
	id: number;
	episode: number;
	/** Unix seconds. */
	airingAt: number;
	media: AniListMedia;
}

/** Shape returned by AIRING_WEEK_QUERY. */
export interface AiringWeekResponse {
	Page: { pageInfo: { hasNextPage: boolean }; airingSchedules: AiringSlot[] };
}

/** Shape returned by LIST_ENTRIES_QUERY. */
export interface ListEntriesResponse {
	Page: {
		mediaList: Array<{ id: number; mediaId: number; status: MediaListStatus; progress: number }>;
	};
}

/** Shape returned by BROWSE_COLLECTIONS_QUERY. */
export interface BrowseCollectionsResponse {
	GenreCollection: string[];
	MediaTagCollection: AniListTag[];
}

/** Shape returned by VIEWER_COUNTS_QUERY. */
export interface ViewerCountsResponse {
	Viewer: {
		id: number;
		statistics: {
			anime: { count: number } | null;
			manga: { count: number } | null;
		} | null;
	};
}

/** Shape returned by PUBLIC_TRENDING_QUERY — see fetchPublicTrending() in client.ts. */
export interface PublicTrendingResponse {
	trending: AniListPage<AniListMedia>;
}

/** One active day in User.stats.activityHistory (roughly the last six months). */
export interface ActivityDay {
	/** Unix seconds, the start of that day. */
	date: number;
	/** List updates that day, anime and manga together. */
	amount: number;
	level: number;
}

/** Shape returned by ACTIVITY_HISTORY_QUERY. */
export interface ActivityHistoryResponse {
	User: { id: number; stats: { activityHistory: ActivityDay[] | null } | null } | null;
}

/** A season-chart title: MEDIA_FIELDS plus what the chart's cards show. */
export interface SeasonMedia extends AniListMedia {
	/** ORIGINAL, MANGA, LIGHT_NOVEL, … */
	source: string | null;
	startDate: AniListDate;
	rankings: Array<{
		rank: number;
		type: 'RATED' | 'POPULAR';
		season: MediaSeason | null;
		year: number | null;
		allTime: boolean;
	}>;
	relations: {
		edges: Array<{
			relationType: string;
			node: { id: number; type: MediaType; title: Omit<AniListMediaTitle, 'native'> };
		}>;
	};
}

/** Shape returned by SEASON_CHART_QUERY. */
export interface SeasonChartResponse {
	Page: { pageInfo: { hasNextPage: boolean }; media: SeasonMedia[] };
}

/** Shape returned by SEASON_LEFTOVERS_QUERY. */
export interface SeasonLeftoversResponse {
	Page: { pageInfo: { hasNextPage: boolean }; airingSchedules: Array<{ media: SeasonMedia }> };
}

// ── Notifications (the top bar's bell; client.ts fetchNotifications) ──

export interface NotificationUser {
	id: number;
	name: string;
	avatar: { medium: string | null } | null;
}

export interface NotificationMedia {
	id: number;
	type: MediaType;
	title: { userPreferred: string | null };
	coverImage: { medium: string | null } | null;
}

/**
 * One of AniList's notification types. Only the fields NOTIFICATIONS_QUERY
 * asks for; a type it has no fragment for arrives with just `__typename`.
 */
export interface AniListNotification {
	__typename: string;
	id?: number;
	/** Unix seconds. */
	createdAt?: number;
	/** The sentence around the subject, e.g. " started following you." */
	context?: string | null;
	/** Airing: the sentence in parts — ["Episode ", " of ", " aired."]. */
	contexts?: Array<string | null> | null;
	episode?: number;
	activityId?: number;
	commentId?: number;
	user?: NotificationUser | null;
	media?: NotificationMedia | null;
	thread?: { id: number; title: string | null } | null;
	deletedMediaTitles?: Array<string | null> | null;
	deletedMediaTitle?: string | null;
}

export interface NotificationsResponse {
	Page: { notifications: AniListNotification[] };
}

// ── Browse's people search (client.ts fetchSearchPeople) ──

export interface SearchPerson {
	id: number;
	name: { userPreferred: string | null };
	image: { large: string | null; medium: string | null } | null;
}

export interface SearchPeopleResponse {
	characters: {
		characters: Array<
			SearchPerson & {
				media: {
					nodes: Array<{
						title: { userPreferred: string | null; english: string | null; romaji: string | null };
					}>;
				} | null;
			}
		>;
	};
	staff: { staff: Array<SearchPerson & { primaryOccupations: string[] | null }> };
	users: {
		users: Array<{
			id: number;
			name: string;
			avatar: { large: string | null; medium: string | null } | null;
		}>;
	};
	studios: {
		studios: Array<{
			id: number;
			name: string;
			siteUrl: string | null;
			isAnimationStudio: boolean;
		}>;
	};
}

// ── Profile (routes/profile; client.ts fetchProfile) ──

export interface FavouritePerson {
	id: number;
	name: { userPreferred: string | null };
	image: { large: string | null; medium: string | null } | null;
	siteUrl: string | null;
}

export interface ProfileResponse {
	Viewer: {
		id: number;
		/** Unix seconds. */
		createdAt: number | null;
		siteUrl: string | null;
		favourites: {
			anime: { nodes: Array<{ id: number }> } | null;
			manga: { nodes: Array<{ id: number }> } | null;
			characters: { nodes: FavouritePerson[] } | null;
			staff: { nodes: FavouritePerson[] } | null;
			studios: { nodes: Array<{ id: number; name: string; siteUrl: string | null }> } | null;
		} | null;
	};
}

/** An account's favourites and when it joined: the viewer's, or anyone's (UserAccount). */
export type ProfileAccount = ProfileResponse['Viewer'];

/** Another user (USER_PROFILE_QUERY): who they are, and their favourites. */
export interface UserAccount extends ProfileAccount {
	name: string;
	/** AniList markdown (see page-data/markdown.ts). */
	about: string | null;
	avatar: { large: string | null } | null;
	bannerImage: string | null;
	/** Whether the viewer follows them; null signed out. */
	isFollowing: boolean | null;
	/** Whether they follow the viewer; null signed out. */
	isFollower: boolean | null;
	/** AniList's headline numbers (the Overview's); mean scores are out of 100. */
	statistics: {
		anime: { count: number; episodesWatched: number; minutesWatched: number; meanScore: number };
		manga: { count: number; chaptersRead: number; volumesRead: number; meanScore: number };
	} | null;
}

/** A profile with its favourite titles filled in (client.ts fetchProfile, fetchUserProfile). */
export interface Profile<A extends ProfileAccount = ProfileAccount> {
	account: A;
	/** Favourite titles, in the order AniList lists them; null when they failed to load. */
	anime: AniListMedia[] | null;
	manga: AniListMedia[] | null;
	/** Why the titles failed to load, when they did. */
	titlesError: string | null;
}

// ── People: staff and characters (STAFF_PAGE_QUERY, CHARACTER_PAGE_QUERY) ──

/** A title in a person's roles: just enough for a cover card. */
export interface PersonMedia {
	id: number;
	type: MediaType;
	format: string | null;
	seasonYear: number | null;
	startDate: { year: number | null };
	title: AniListMediaTitle;
	coverImage: { large: string | null; color: string | null };
	isAdult: boolean;
}

export interface PersonPageInfo {
	/** Unreliable on some queries; paging follows `hasNextPage`. */
	total: number | null;
	hasNextPage: boolean;
}

export interface PersonName {
	full: string;
	native: string | null;
	userPreferred: string | null;
	alternative: string[] | null;
}

/** A voice actor's roles: one edge per title, with the characters voiced in it. */
export interface StaffVoiceRoles {
	pageInfo: PersonPageInfo;
	edges: Array<{
		characterRole: 'MAIN' | 'SUPPORTING' | 'BACKGROUND' | null;
		characters: Array<{
			id: number;
			name: { full: string; userPreferred: string | null };
			image: { medium: string | null } | null;
		} | null>;
		node: PersonMedia;
	}>;
}

/** Production credits (story, art, direction, theme songs): one edge per role. */
export interface StaffCredits {
	pageInfo: PersonPageInfo;
	edges: Array<{ staffRole: string | null; node: PersonMedia }>;
}

/** A studio's titles, main productions and the ones it only helped on. */
export interface StudioMedia {
	pageInfo: PersonPageInfo;
	edges: Array<{ isMainStudio: boolean; node: PersonMedia }>;
}

/** A studio page (client.ts fetchStudio). */
export interface StudioPage {
	id: number;
	name: string;
	isAnimationStudio: boolean;
	siteUrl: string | null;
	favourites: number | null;
	isFavourite: boolean;
	media: StudioMedia;
}

export interface StaffPerson {
	id: number;
	name: PersonName;
	image: { large: string | null } | null;
	/** AniList markdown (see page-data/markdown.ts). */
	description: string | null;
	primaryOccupations: string[] | null;
	gender: string | null;
	languageV2: string | null;
	dateOfBirth: AniListDate;
	dateOfDeath: AniListDate;
	age: number | null;
	/** [start] while active, [start, end] once they stopped. */
	yearsActive: number[] | null;
	homeTown: string | null;
	bloodType: string | null;
	favourites: number | null;
	isFavourite: boolean;
	siteUrl: string | null;
	characterMedia: StaffVoiceRoles;
	staffMedia: StaffCredits;
}

/** The titles a character is in, with their voice actors in every language. */
export interface CharacterAppearances {
	pageInfo: PersonPageInfo;
	edges: Array<{
		characterRole: 'MAIN' | 'SUPPORTING' | 'BACKGROUND' | null;
		voiceActorRoles: Array<{
			roleNotes: string | null;
			voiceActor: {
				id: number;
				name: { full: string; userPreferred: string | null };
				image: { medium: string | null } | null;
				languageV2: string | null;
			} | null;
		}> | null;
		node: PersonMedia;
	}>;
}

export interface CharacterPerson {
	id: number;
	name: PersonName & {
		/** Names that give away the story. */
		alternativeSpoiler: string[] | null;
	};
	image: { large: string | null } | null;
	/** AniList markdown (see page-data/markdown.ts). */
	description: string | null;
	gender: string | null;
	/** Free text: "17", "1000+", "Teens". */
	age: string | null;
	bloodType: string | null;
	dateOfBirth: AniListDate;
	favourites: number | null;
	isFavourite: boolean;
	siteUrl: string | null;
	media: CharacterAppearances;
}
