// Shared by every query that returns Media — AniList needs the fragment
// definition inlined in each query document that spreads it.
const MEDIA_FIELDS = `
  fragment MediaFields on Media {
    id
    type
    format
    status
    season
    seasonYear
    episodes
    duration
    chapters
    volumes
    averageScore
    popularity
    favourites
    isAdult
    title {
      romaji
      english
      native
      userPreferred
    }
    description(asHtml: false)
    genres
    coverImage {
      extraLarge
      large
      medium
      color
    }
    bannerImage
    studios(isMain: true) {
      nodes {
        id
        name
        siteUrl
      }
    }
    nextAiringEpisode {
      episode
      airingAt
      timeUntilAiring
    }
  }
`;

// ── Live: used by client.ts for the real auth flow ──

export const VIEWER_QUERY = `
  query GetViewer {
    Viewer {
      id
      name
      avatar {
        large
        medium
      }
      bannerImage
      unreadNotificationCount
      mediaListOptions {
        scoreFormat
        # every custom list's name, empty ones too (the list collection
        # leaves those out): the editor offers them
        animeList {
          customLists
        }
        mangaList {
          customLists
        }
      }
      options {
        titleLanguage
        displayAdultContent
        airingNotifications
      }
    }
  }
`;

const SAVED_ENTRY_FIELDS = `
  id
  mediaId
  status
  progress
  progressVolumes
  score
  repeat
  notes
  private
  priority
  # [{ name, enabled }] for every custom list of the entry's type; null with none
  customLists(asArray: true)
  startedAt {
    year
    month
    day
  }
  completedAt {
    year
    month
    day
  }
`;

// Variables left out of the request are left unchanged on AniList, so
// saveEntry() only sends the fields being edited. `score` is in the viewer's
// own mediaListOptions.scoreFormat.
export const SAVE_ENTRY_MUTATION = `
  mutation SaveEntry(
    $mediaId: Int
    $status: MediaListStatus
    $progress: Int
    $progressVolumes: Int
    $score: Float
    $repeat: Int
    $notes: String
    $private: Boolean
    $priority: Int
    $startedAt: FuzzyDateInput
    $completedAt: FuzzyDateInput
    $customLists: [String]
  ) {
    SaveMediaListEntry(
      mediaId: $mediaId
      status: $status
      progress: $progress
      progressVolumes: $progressVolumes
      score: $score
      repeat: $repeat
      notes: $notes
      private: $private
      priority: $priority
      startedAt: $startedAt
      completedAt: $completedAt
      customLists: $customLists
    ) {
      ${SAVED_ENTRY_FIELDS}
    }
  }
`;

export const DELETE_ENTRY_MUTATION = `
  mutation DeleteEntry($id: Int) {
    DeleteMediaListEntry(id: $id) {
      deleted
    }
  }
`;

// ── Live: used by client.ts fetchHomeData() for the real Home feed.
// Field set verified working against the real AniList API. `continueList`
// is the one addition beyond what was verified — `Viewer`/`User` has no
// `mediaList` field (confirmed by testing), so list entries have to come
// from the top-level `Page.mediaList(userId: ...)` field instead, same
// pattern as the other three Page fields below. ──

// ── Home: two queries so a failure only takes down its own section ──

/** The viewer's in-progress list (Continue + hero), and whether the list has anything at all. */
export const HOME_LIST_QUERY = `
  query HomeList($userId: Int!, $type: MediaType!, $perPage: Int = 10) {
    continueList: Page(perPage: $perPage) {
      mediaList(
        userId: $userId
        type: $type
        status_in: [CURRENT, REPEATING, PAUSED]
        sort: UPDATED_TIME_DESC
      ) {
        id
        progress
        status
        updatedAt
        media {
          ...MediaFields
        }
      }
    }

    upNext: Page(perPage: 12) {
      mediaList(
        userId: $userId
        type: $type
        status: PLANNING
        sort: [PRIORITY_DESC, UPDATED_TIME_DESC]
      ) {
        id
        progress
        status
        updatedAt
        media {
          ...MediaFields
        }
      }
    }

    anyEntry: Page(perPage: 1) {
      mediaList(userId: $userId, type: $type) {
        id
      }
    }
  }

  ${MEDIA_FIELDS}
`;

/**
 * Trending / popular / upcoming rows. Each title carries the viewer's own
 * list entry (null when not on the list, or when signed out), so cards show
 * list state for every title — not just the ones in Continue.
 */
export const HOME_FEED_QUERY = `
  query HomeFeed(
    $type: MediaType!
    $season: MediaSeason
    $seasonYear: Int
    $nextSeason: MediaSeason
    $nextSeasonYear: Int
    $perPage: Int = 10
  ) {
    trending: Page(perPage: $perPage) {
      media(type: $type, sort: TRENDING_DESC) {
        ...FeedMedia
      }
    }

    popularThisSeason: Page(perPage: $perPage) {
      media(
        type: $type
        season: $season
        seasonYear: $seasonYear
        status: RELEASING
        sort: POPULARITY_DESC
      ) {
        ...FeedMedia
      }
    }

    upcoming: Page(perPage: $perPage) {
      media(
        type: $type
        season: $nextSeason
        seasonYear: $nextSeasonYear
        status: NOT_YET_RELEASED
        sort: POPULARITY_DESC
      ) {
        ...FeedMedia
      }
    }
  }

  fragment FeedMedia on Media {
    ...MediaFields
    mediaListEntry {
      id
      status
      progress
    }
  }

  ${MEDIA_FIELDS}
`;

/** First-run setup: how much was "imported" from the AniList account. */
export const VIEWER_COUNTS_QUERY = `
  query ViewerCounts {
    Viewer {
      id
      statistics {
        anime {
          count
        }
        manga {
          count
        }
      }
    }
  }
`;

/** Account settings miruyo follows — written back to AniList, the one source of truth. */
export const UPDATE_SETTINGS_MUTATION = `
  mutation UpdateSettings(
    $titleLanguage: UserTitleLanguage
    $displayAdultContent: Boolean
    $airingNotifications: Boolean
    $scoreFormat: ScoreFormat
  ) {
    UpdateUser(
      titleLanguage: $titleLanguage
      displayAdultContent: $displayAdultContent
      airingNotifications: $airingNotifications
      scoreFormat: $scoreFormat
    ) {
      id
      options {
        titleLanguage
        displayAdultContent
        airingNotifications
      }
      mediaListOptions {
        scoreFormat
      }
    }
  }
`;

/** No Viewer/User field, so no auth token needed — used for the logged-out Home. */
export const PUBLIC_TRENDING_QUERY = `
  query PublicTrending($type: MediaType!, $perPage: Int = 16) {
    trending: Page(perPage: $perPage) {
      media(type: $type, sort: TRENDING_DESC) {
        ...MediaFields
      }
    }
  }

  ${MEDIA_FIELDS}
`;

// ── Browse ──

/**
 * One page of Browse results. Every filter is optional: AniList ignores
 * null arguments. Variables are built by toQueryVariables() in browse/params.ts.
 *
 * No `mediaListEntry` here: on this query AniList answers it with a 500
 * (signed in or not). The viewer's entries come from LIST_ENTRIES_QUERY.
 */
export const BROWSE_QUERY = `
  query Browse(
    $page: Int = 1
    $perPage: Int = 30
    $type: MediaType!
    $search: String
    $genres: [String]
    $tags: [String]
    $notGenres: [String]
    $notTags: [String]
    $formats: [MediaFormat]
    $status: MediaStatus
    $season: MediaSeason
    $seasonYear: Int
    $country: CountryCode
    $scoreAbove: Int
    $scoreBelow: Int
    $onList: Boolean
    $isAdult: Boolean
    $sort: [MediaSort]
  ) {
    Page(page: $page, perPage: $perPage) {
      pageInfo {
        total
        currentPage
        hasNextPage
      }
      media(
        type: $type
        search: $search
        genre_in: $genres
        tag_in: $tags
        genre_not_in: $notGenres
        tag_not_in: $notTags
        format_in: $formats
        status: $status
        season: $season
        seasonYear: $seasonYear
        countryOfOrigin: $country
        averageScore_greater: $scoreAbove
        averageScore_lesser: $scoreBelow
        onList: $onList
        isAdult: $isAdult
        sort: $sort
      ) {
        ...MediaFields
      }
    }
  }

  ${MEDIA_FIELDS}
`;

/** The viewer's list entries for specific titles — list state for Browse results. */
export const LIST_ENTRIES_QUERY = `
  query ListEntries($userId: Int!, $ids: [Int], $perPage: Int = 50) {
    Page(perPage: $perPage) {
      mediaList(userId: $userId, mediaId_in: $ids) {
        id
        mediaId
        status
        progress
      }
    }
  }
`;

/** Every genre and tag AniList knows — for the filter rail. Changes rarely. */
export const BROWSE_COLLECTIONS_QUERY = `
  query BrowseCollections {
    GenreCollection
    MediaTagCollection {
      name
      category
      isAdult
    }
  }
`;

/**
 * The characters, staff, users and studios a Browse search also matches,
 * best match first. Public: sent without a token. A character carries its
 * best-known title, so "Frieren" can say which one.
 */
export const SEARCH_PEOPLE_QUERY = `
  query SearchPeople($search: String!, $perPage: Int = 8) {
    characters: Page(perPage: $perPage) {
      characters(search: $search, sort: [SEARCH_MATCH, FAVOURITES_DESC]) {
        id
        name { userPreferred }
        image { large medium }
        media(perPage: 1, sort: [POPULARITY_DESC]) {
          nodes { title { userPreferred english romaji } }
        }
      }
    }
    staff: Page(perPage: $perPage) {
      staff(search: $search, sort: [SEARCH_MATCH, FAVOURITES_DESC]) {
        id
        name { userPreferred }
        image { large medium }
        primaryOccupations
      }
    }
    users: Page(perPage: $perPage) {
      users(search: $search, sort: [SEARCH_MATCH]) {
        id
        name
        avatar { large medium }
      }
    }
    studios: Page(perPage: 6) {
      studios(search: $search, sort: [SEARCH_MATCH]) {
        id
        name
        siteUrl
        isAnimationStudio
      }
    }
  }
`;

// ── Title detail ──

/**
 * A title's Stats tab: how AniList's users score it and where it sits on
 * their lists, and its rankings. Loaded when the tab opens, so the page's
 * first load stays as it was. Public: sent without a token.
 */
export const TITLE_STATS_QUERY = `
  query TitleStats($id: Int!) {
    Media(id: $id) {
      id
      averageScore
      favourites
      stats {
        scoreDistribution { score amount }
        statusDistribution { status amount }
      }
      rankings { id rank type format year season allTime context }
    }
  }
`;

/**
 * Everything the title page shows. Checked against the live API (signed
 * out) before use — see BROWSE_QUERY for why. `mediaListEntry` and
 * `isFavourite` are only meaningful with a token (null / false without).
 */
export const DETAIL_QUERY = `
  query Detail($id: Int!) {
    Media(id: $id) {
      ...MediaFields
      source
      synonyms
      isFavourite
      tags {
        id
        name
        rank
        description
        isMediaSpoiler
        isGeneralSpoiler
        isAdult
      }
      externalLinks {
        id
        url
        site
        type
        language
        color
        icon
        notes
        isDisabled
      }
      startDate {
        year
        month
        day
      }
      endDate {
        year
        month
        day
      }
      rankings {
        rank
        type
        allTime
        context
      }
      trailer {
        id
        site
        thumbnail
      }
      staff(perPage: 6, sort: [RELEVANCE]) {
        edges {
          role
          node {
            id
            name {
              full
            }
            image {
              medium
            }
          }
        }
      }
      characters(perPage: 12, sort: [ROLE, RELEVANCE]) {
        edges {
          role
          node {
            id
            name {
              full
            }
            image {
              medium
            }
          }
          voiceActors(language: JAPANESE, sort: [RELEVANCE]) {
            id
            name {
              full
            }
            image {
              medium
            }
          }
        }
      }
      relations {
        edges {
          relationType(version: 2)
          node {
            id
            type
            format
            status
            episodes
            chapters
            seasonYear
            startDate {
              year
              month
              day
            }
            title {
              romaji
              english
              userPreferred
            }
            coverImage {
              large
              color
            }
          }
        }
      }
      recommendations(perPage: 6, sort: [RATING_DESC]) {
        nodes {
          mediaRecommendation {
            ...MediaFields
          }
        }
      }
      mediaListEntry {
        ${SAVED_ENTRY_FIELDS}
      }
    }
  }

  ${MEDIA_FIELDS}
`;

/** One list entry, for the editor when it's opened from a card. */
export const ENTRY_QUERY = `
  query Entry($userId: Int!, $mediaId: Int!) {
    MediaList(userId: $userId, mediaId: $mediaId) {
      ${SAVED_ENTRY_FIELDS}
    }
  }
`;

export const TOGGLE_FAVOURITE_MUTATION = `
  mutation ToggleFavourite(
    $animeId: Int
    $mangaId: Int
    $characterId: Int
    $staffId: Int
    $studioId: Int
  ) {
    ToggleFavourite(
      animeId: $animeId
      mangaId: $mangaId
      characterId: $characterId
      staffId: $staffId
      studioId: $studioId
    ) {
      anime(perPage: 1) {
        pageInfo {
          total
        }
      }
    }
  }
`;

// ── My List ──

/**
 * The fields a list row needs — lighter than MEDIA_FIELDS (no description or
 * banner), since a list can hold thousands of titles.
 */
const LIST_MEDIA_FIELDS = `
  fragment ListMedia on Media {
    id
    type
    format
    status
    season
    seasonYear
    episodes
    duration
    chapters
    volumes
    averageScore
    popularity
    isAdult
    countryOfOrigin
    startDate {
      year
    }
    title {
      romaji
      english
      native
      userPreferred
    }
    genres
    coverImage {
      extraLarge
      large
      medium
      color
    }
    studios(isMain: true) {
      nodes {
        id
        name
      }
    }
    nextAiringEpisode {
      episode
      airingAt
      timeUntilAiring
    }
  }
`;

/** The viewer's whole list for one type, grouped by status (custom lists are skipped). */
export const LIST_COLLECTION_QUERY = `
  query ListCollection($userId: Int!, $type: MediaType!) {
    MediaListCollection(userId: $userId, type: $type) {
      lists {
        name
        status
        isCustomList
        entries {
          ${SAVED_ENTRY_FIELDS}
          updatedAt
          media {
            ...ListMedia
          }
        }
      }
    }
  }

  ${LIST_MEDIA_FIELDS}
`;

// ── Seasonal ──

/**
 * Every episode airing in a time window, soonest first — a week is ~100-150
 * airings, so this is paged (50 at a time). List state comes separately
 * (loadListState), as with Browse.
 */
export const AIRING_WEEK_QUERY = `
  query AiringWeek($start: Int!, $end: Int!, $page: Int = 1) {
    Page(page: $page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) {
        id
        episode
        airingAt
        media {
          ...ListMedia
        }
      }
    }
  }

  ${LIST_MEDIA_FIELDS}
`;

/**
 * Manga for "New releases": AniList has no per-chapter release data, so this
 * is popular series that started serializing recently and are still running.
 */
export const NEW_MANGA_QUERY = `
  query NewManga($since: FuzzyDateInt, $perPage: Int = 24, $isAdult: Boolean) {
    Page(perPage: $perPage) {
      media(
        type: MANGA
        status: RELEASING
        startDate_greater: $since
        sort: POPULARITY_DESC
        isAdult: $isAdult
      ) {
        ...ListMedia
      }
    }
  }

  ${LIST_MEDIA_FIELDS}
`;

// ── Stats ──

/**
 * Daily list activity for the Stats heatmap. AniList keeps about six months
 * and doesn't split it by anime and manga. (The rest of Stats is computed
 * from LIST_COLLECTION_QUERY: User.statistics' breakdowns are often stale.)
 */
export const ACTIVITY_HISTORY_QUERY = `
  query ActivityHistory($userId: Int!) {
    User(id: $userId) {
      id
      stats {
        activityHistory {
          date
          amount
          level
        }
      }
    }
  }
`;

// ── Season chart ──

/** A season-chart card: the full media fields plus source, start, ranks and prequel. */
const SEASON_MEDIA_FIELDS = `
  fragment SeasonMedia on Media {
    ...MediaFields
    source
    startDate {
      year
      month
      day
    }
    rankings {
      rank
      type
      season
      year
      allTime
    }
    relations {
      edges {
        relationType
        node {
          id
          type
          title {
            romaji
            english
            userPreferred
          }
        }
      }
    }
  }

  ${MEDIA_FIELDS}
`;

/** Everything premiering in a season, most popular first (~100 titles, 2 pages). */
export const SEASON_CHART_QUERY = `
  query SeasonChart($season: MediaSeason!, $year: Int!, $page: Int = 1, $isAdult: Boolean) {
    Page(page: $page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      media(
        type: ANIME
        season: $season
        seasonYear: $year
        sort: POPULARITY_DESC
        isAdult: $isAdult
      ) {
        ...SeasonMedia
      }
    }
  }

  ${SEASON_MEDIA_FIELDS}
`;

/**
 * "Leftovers": AniList has no such filter, so this takes a week of airings
 * (the season's second, after last season's finales) and the caller keeps
 * the shows that started before the season.
 */
export const SEASON_LEFTOVERS_QUERY = `
  query SeasonLeftovers($start: Int!, $end: Int!, $page: Int = 1) {
    Page(page: $page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) {
        media {
          ...SeasonMedia
        }
      }
    }
  }

  ${SEASON_MEDIA_FIELDS}
`;

const NOTIFICATION_USER = `user { id name avatar { medium } }`;
const NOTIFICATION_MEDIA = `media { id type title { userPreferred } coverImage { medium } }`;
const NOTIFICATION_THREAD = `thread { id title }`;

/**
 * The viewer's latest notifications, newest first. Fetching them marks them
 * read on AniList (`resetNotificationCount`), as opening AniList's own page does.
 */
export const NOTIFICATIONS_QUERY = `
  query Notifications($perPage: Int) {
    Page(page: 1, perPage: $perPage) {
      notifications(resetNotificationCount: true) {
        __typename
        ... on AiringNotification { id createdAt episode contexts ${NOTIFICATION_MEDIA} }
        ... on FollowingNotification { id createdAt context ${NOTIFICATION_USER} }
        ... on ActivityMessageNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ActivityMentionNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ActivityReplyNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ActivityReplySubscribedNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ActivityLikeNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ActivityReplyLikeNotification { id createdAt context activityId ${NOTIFICATION_USER} }
        ... on ThreadCommentMentionNotification { id createdAt context commentId ${NOTIFICATION_THREAD} ${NOTIFICATION_USER} }
        ... on ThreadCommentReplyNotification { id createdAt context commentId ${NOTIFICATION_THREAD} ${NOTIFICATION_USER} }
        ... on ThreadCommentSubscribedNotification { id createdAt context commentId ${NOTIFICATION_THREAD} ${NOTIFICATION_USER} }
        ... on ThreadCommentLikeNotification { id createdAt context commentId ${NOTIFICATION_THREAD} ${NOTIFICATION_USER} }
        ... on ThreadLikeNotification { id createdAt context ${NOTIFICATION_THREAD} ${NOTIFICATION_USER} }
        ... on RelatedMediaAdditionNotification { id createdAt context ${NOTIFICATION_MEDIA} }
        ... on MediaDataChangeNotification { id createdAt context ${NOTIFICATION_MEDIA} }
        ... on MediaMergeNotification { id createdAt context deletedMediaTitles ${NOTIFICATION_MEDIA} }
        ... on MediaDeletionNotification { id createdAt context deletedMediaTitle }
      }
    }
  }
`;

/** Just the unread count, to refresh the bell without refetching the viewer. */
export const UNREAD_COUNT_QUERY = `
  query UnreadCount {
    Viewer {
      id
      unreadNotificationCount
    }
  }
`;

const PROFILE_PEOPLE = `nodes { id name { userPreferred } image { large medium } siteUrl }`;

/**
 * The profile page: when the account was made, and its favourites. Titles
 * come back as ids only: asked through favourites, AniList answered every
 * title with an Internal Server Error (one per title, on the live API), so
 * FAVOURITE_MEDIA_QUERY fetches them directly, as the rest of the app does.
 */
const PROFILE_FAVOURITES = `
  favourites {
    anime(page: 1, perPage: $perPage) { nodes { id } }
    manga(page: 1, perPage: $perPage) { nodes { id } }
    characters(page: 1, perPage: $peoplePerPage) { ${PROFILE_PEOPLE} }
    staff(page: 1, perPage: $peoplePerPage) { ${PROFILE_PEOPLE} }
    studios(page: 1, perPage: $peoplePerPage) { nodes { id name siteUrl } }
  }
`;

/** Someone else's profile, by name (AniList matches it whatever the case). */
export const USER_PROFILE_QUERY = `
  query UserProfile($name: String!, $perPage: Int = 7, $peoplePerPage: Int = 10) {
    User(name: $name) {
      id
      name
      about(asHtml: false)
      avatar {
        large
      }
      bannerImage
      createdAt
      siteUrl
      isFollowing
      isFollower
      statistics {
        anime {
          count
          episodesWatched
          minutesWatched
          meanScore
        }
        manga {
          count
          chaptersRead
          volumesRead
          meanScore
        }
      }
      ${PROFILE_FAVOURITES}
    }
  }
`;

export const TOGGLE_FOLLOW_MUTATION = `
  mutation ToggleFollow($userId: Int!) {
    ToggleFollow(userId: $userId) {
      id
      isFollowing
    }
  }
`;

/** Favourite titles by id (anime and manga together). */
export const FAVOURITE_MEDIA_QUERY = `
  query FavouriteMedia($ids: [Int]) {
    Page(perPage: 50) {
      media(id_in: $ids) {
        ...ListMedia
        mediaListEntry {
          id
          status
          progress
        }
      }
    }
  }

  ${LIST_MEDIA_FIELDS}
`;

/**
 * For You: AniList's recommendations for each seed, one aliased Media(id:)
 * per seed (the shape the title page's "If you like this" already uses).
 * Seed ids are integers from the viewer's own list.
 */
/**
 * For You's cross-mode picks: the related titles of a few titles you loved on
 * your other list, read for their source (an anime's manga) or adaptations
 * (a manga's anime). One request for every seed; checked against the live
 * API (signed out) before use.
 */
export function forYouRelationsQuery(seedIds: number[]): string {
	const seeds = seedIds
		.map(
			(id, i) => `
    s${i}: Media(id: ${Math.trunc(id)}) {
      id
      relations {
        edges {
          relationType(version: 2)
          node {
            ...ListMedia
            bannerImage
            description(asHtml: false)
            mediaListEntry {
              id
              status
              progress
            }
          }
        }
      }
    }`
		)
		.join('');
	return `
  query ForYouRelations {${seeds}
  }

  ${LIST_MEDIA_FIELDS}
`;
}

// 20 a seed, so more titles are recommended by more than one seed (checked
// against the live API with eight seeds: within AniList's limits)
export function forYouQuery(seedIds: number[], perSeed = 20): string {
	const seeds = seedIds
		.map(
			(id, i) => `
    s${i}: Media(id: ${Math.trunc(id)}) {
      id
      recommendations(perPage: ${perSeed}, sort: [RATING_DESC]) {
        nodes {
          rating
          mediaRecommendation {
            ...ListMedia
            # Home's hero shows a pick with its banner and synopsis
            bannerImage
            description(asHtml: false)
            mediaListEntry {
              id
              status
              progress
            }
          }
        }
      }
    }`
		)
		.join('');
	return `
  query ForYou {${seeds}
  }

  ${LIST_MEDIA_FIELDS}
`;
}

// ── People: staff and characters ──

const PERSON_MEDIA = `
  id
  type
  format
  seasonYear
  startDate {
    year
  }
  title {
    romaji
    english
    native
    userPreferred
  }
  coverImage {
    large
    color
  }
  isAdult
`;

const PERSON_NAME = `
  name {
    full
    native
    userPreferred
    alternative
  }
`;

const STAFF_VOICE_ROLES = `
  pageInfo {
    total
    hasNextPage
  }
  edges {
    characterRole
    characters {
      id
      name {
        full
        userPreferred
      }
      image {
        medium
      }
    }
    node {
      ${PERSON_MEDIA}
    }
  }
`;

const STAFF_CREDITS = `
  pageInfo {
    total
    hasNextPage
  }
  edges {
    staffRole
    node {
      ${PERSON_MEDIA}
    }
  }
`;

// AniList returns at most 25 of a person's roles a page, whatever's asked for

/** A staff page: who they are, then the first page of their voice roles and credits. */
export const STAFF_PAGE_QUERY = `
  query StaffPage($id: Int!, $sort: [MediaSort], $perPage: Int = 25) {
    Staff(id: $id) {
      id
      ${PERSON_NAME}
      image {
        large
      }
      description(asHtml: false)
      primaryOccupations
      gender
      languageV2
      dateOfBirth {
        year
        month
        day
      }
      dateOfDeath {
        year
        month
        day
      }
      age
      yearsActive
      homeTown
      bloodType
      favourites
      isFavourite
      siteUrl
      characterMedia(page: 1, perPage: $perPage, sort: $sort) {
        ${STAFF_VOICE_ROLES}
      }
      staffMedia(page: 1, perPage: $perPage, sort: $sort) {
        ${STAFF_CREDITS}
      }
    }
  }
`;

/** More of a voice actor's roles ("Load more"). */
export const STAFF_VOICE_ROLES_QUERY = `
  query StaffVoiceRoles($id: Int!, $page: Int!, $sort: [MediaSort], $perPage: Int = 25) {
    Staff(id: $id) {
      id
      characterMedia(page: $page, perPage: $perPage, sort: $sort) {
        ${STAFF_VOICE_ROLES}
      }
    }
  }
`;

/** More of someone's production credits ("Load more"). */
export const STAFF_CREDITS_QUERY = `
  query StaffCredits($id: Int!, $page: Int!, $sort: [MediaSort], $perPage: Int = 25) {
    Staff(id: $id) {
      id
      staffMedia(page: $page, perPage: $perPage, sort: $sort) {
        ${STAFF_CREDITS}
      }
    }
  }
`;

const STUDIO_MEDIA = `
  pageInfo {
    total
    hasNextPage
  }
  edges {
    isMainStudio
    node {
      ${PERSON_MEDIA}
    }
  }
`;

/**
 * A studio page: the studio, then the first page of its titles. Checked
 * against the live API (signed out) before use.
 */
export const STUDIO_PAGE_QUERY = `
  query StudioPage($id: Int!, $sort: [MediaSort], $perPage: Int = 25) {
    Studio(id: $id) {
      id
      name
      isAnimationStudio
      siteUrl
      favourites
      isFavourite
      media(page: 1, perPage: $perPage, sort: $sort) {
        ${STUDIO_MEDIA}
      }
    }
  }
`;

/** Another page of a studio's titles. */
export const STUDIO_MEDIA_QUERY = `
  query StudioMedia($id: Int!, $page: Int!, $sort: [MediaSort], $perPage: Int = 25) {
    Studio(id: $id) {
      id
      media(page: $page, perPage: $perPage, sort: $sort) {
        ${STUDIO_MEDIA}
      }
    }
  }
`;

const CHARACTER_APPEARANCES = `
  pageInfo {
    total
    hasNextPage
  }
  edges {
    characterRole
    voiceActorRoles(sort: [RELEVANCE, ID]) {
      roleNotes
      voiceActor {
        id
        name {
          full
          userPreferred
        }
        image {
          medium
        }
        languageV2
      }
    }
    node {
      ${PERSON_MEDIA}
    }
  }
`;

/** A character page: who they are, then the first page of the titles they're in. */
export const CHARACTER_PAGE_QUERY = `
  query CharacterPage($id: Int!, $perPage: Int = 25) {
    Character(id: $id) {
      id
      name {
        full
        native
        userPreferred
        alternative
        alternativeSpoiler
      }
      image {
        large
      }
      description(asHtml: false)
      gender
      age
      bloodType
      dateOfBirth {
        year
        month
        day
      }
      favourites
      isFavourite
      siteUrl
      media(page: 1, perPage: $perPage, sort: [POPULARITY_DESC]) {
        ${CHARACTER_APPEARANCES}
      }
    }
  }
`;

/** More of the titles a character is in ("Load more"). */
export const CHARACTER_APPEARANCES_QUERY = `
  query CharacterAppearances($id: Int!, $page: Int!, $perPage: Int = 25) {
    Character(id: $id) {
      id
      media(page: $page, perPage: $perPage, sort: [POPULARITY_DESC]) {
        ${CHARACTER_APPEARANCES}
      }
    }
  }
`;

/**
 * Someone else's list, as anyone sees it (private entries left out). Scores
 * come on one scale (10 with decimals) whoever's asking, so their stats and
 * scores read the same for every viewer.
 */
export const USER_LIST_QUERY = `
  query UserList($userId: Int!, $type: MediaType!) {
    MediaListCollection(userId: $userId, type: $type) {
      lists {
        status
        isCustomList
        entries {
          id
          mediaId
          status
          progress
          progressVolumes
          score(format: POINT_10_DECIMAL)
          repeat
          updatedAt
          startedAt {
            year
            month
            day
          }
          completedAt {
            year
            month
            day
          }
          media {
            ...ListMedia
          }
        }
      }
    }
  }

  ${LIST_MEDIA_FIELDS}
`;
