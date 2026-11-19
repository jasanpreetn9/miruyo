// Test-only builders for AniList API shapes — imported by *.test.ts files,
// never by app code.
import type {
	AniListMedia,
	AniListMediaListEntry,
	CharacterPerson,
	CollectionEntry,
	DetailMedia,
	HomeFeedResponse,
	HomeListResponse,
	PersonMedia,
	StaffPerson
} from './types.ts';

export function makeMedia(overrides: Partial<AniListMedia> = {}): AniListMedia {
	return {
		id: 1,
		type: 'ANIME',
		format: 'TV',
		status: 'RELEASING',
		season: 'FALL',
		seasonYear: 2026,
		episodes: 24,
		duration: 24,
		chapters: null,
		volumes: null,
		averageScore: 85,
		popularity: 1000,
		favourites: 100,
		isAdult: false,
		title: { romaji: 'Romaji Title', english: 'English Title', native: null, userPreferred: null },
		description: 'A synopsis.',
		genres: ['Action', 'Fantasy'],
		coverImage: { extraLarge: null, large: null, medium: null, color: '#d9a75e' },
		bannerImage: null,
		studios: { nodes: [{ id: 1, name: 'Studio One', siteUrl: null }] },
		nextAiringEpisode: null,
		...overrides
	};
}

export function makeManga(overrides: Partial<AniListMedia> = {}): AniListMedia {
	return makeMedia({
		type: 'MANGA',
		format: 'MANGA',
		season: null,
		seasonYear: null,
		episodes: null,
		duration: null,
		chapters: 120,
		studios: { nodes: [] },
		...overrides
	});
}

export function makeEntry(
	media: AniListMedia,
	overrides: Partial<Omit<AniListMediaListEntry, 'media'>> = {}
): AniListMediaListEntry {
	return { id: media.id * 10, status: 'CURRENT', progress: 5, updatedAt: 0, media, ...overrides };
}

export function makeHomeList(
	continueList: AniListMediaListEntry[] = [],
	{ anyEntry = continueList.length > 0 }: { anyEntry?: boolean } = {}
): HomeListResponse {
	return {
		continueList: { mediaList: continueList },
		anyEntry: { mediaList: anyEntry ? [{ id: 1 }] : [] }
	};
}

export function makeHomeFeed(
	overrides: { trending?: AniListMedia[]; popular?: AniListMedia[]; upcoming?: AniListMedia[] } = {}
): HomeFeedResponse {
	return {
		trending: { media: overrides.trending ?? [] },
		popularThisSeason: { media: overrides.popular ?? [] },
		upcoming: { media: overrides.upcoming ?? [] }
	};
}

export function makeDetail(overrides: Partial<DetailMedia> = {}): DetailMedia {
	const empty = { year: null, month: null, day: null };
	return {
		...makeMedia(),
		source: 'MANGA',
		synonyms: [],
		isFavourite: false,
		tags: [],
		externalLinks: [],
		startDate: { year: 2026, month: 10, day: 2 },
		endDate: empty,
		rankings: [],
		trailer: null,
		staff: { edges: [] },
		characters: { edges: [] },
		relations: { edges: [] },
		recommendations: { nodes: [] },
		mediaListEntry: null,
		...overrides
	};
}

export function makeCollectionEntry(
	media: AniListMedia,
	overrides: Partial<Omit<CollectionEntry, 'media'>> = {}
): CollectionEntry {
	const empty = { year: null, month: null, day: null };
	return {
		id: media.id * 10,
		mediaId: media.id,
		status: 'CURRENT',
		progress: 5,
		progressVolumes: null,
		score: 0,
		repeat: 0,
		notes: null,
		private: false,
		startedAt: empty,
		completedAt: empty,
		updatedAt: 1_800_000_000,
		media,
		...overrides
	};
}

export function makePersonMedia(overrides: Partial<PersonMedia> = {}): PersonMedia {
	return {
		id: 1,
		type: 'ANIME',
		format: 'TV',
		seasonYear: 2023,
		startDate: { year: 2023 },
		title: { romaji: 'Romaji Title', english: 'English Title', native: null, userPreferred: null },
		coverImage: { large: 'https://s4.anilist.co/cover.jpg', color: '#d9a75e' },
		isAdult: false,
		...overrides
	};
}

export function makeStaff(overrides: Partial<StaffPerson> = {}): StaffPerson {
	const empty = { year: null, month: null, day: null };
	return {
		id: 112215,
		name: { full: 'Atsumi Tanezaki', native: '種﨑敦美', userPreferred: null, alternative: [] },
		image: { large: 'https://s4.anilist.co/staff.jpg' },
		description: null,
		primaryOccupations: ['Voice Actor'],
		gender: 'Female',
		languageV2: 'Japanese',
		dateOfBirth: { year: 1990, month: 9, day: 27 },
		dateOfDeath: empty,
		age: 36,
		yearsActive: [2008],
		homeTown: null,
		bloodType: null,
		favourites: 3922,
		isFavourite: false,
		siteUrl: 'https://anilist.co/staff/112215',
		characterMedia: { pageInfo: { total: 0, hasNextPage: false }, edges: [] },
		staffMedia: { pageInfo: { total: 0, hasNextPage: false }, edges: [] },
		...overrides
	};
}

export function makeCharacter(overrides: Partial<CharacterPerson> = {}): CharacterPerson {
	return {
		id: 176754,
		name: {
			full: 'Frieren',
			native: 'フリーレン',
			userPreferred: null,
			alternative: [],
			alternativeSpoiler: []
		},
		image: { large: 'https://s4.anilist.co/character.jpg' },
		description: null,
		gender: 'Female',
		age: '1000+',
		bloodType: null,
		dateOfBirth: { year: null, month: null, day: null },
		favourites: 22589,
		isFavourite: false,
		siteUrl: 'https://anilist.co/character/176754',
		media: { pageInfo: { total: 0, hasNextPage: false }, edges: [] },
		...overrides
	};
}
