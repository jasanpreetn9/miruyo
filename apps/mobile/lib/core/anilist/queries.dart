// AniList GraphQL documents, ported verbatim from apps/web/src/lib/anilist/queries.ts
// (the web app's queries are verified against the live API). Keep the two in
// step: a fix to a query there belongs here too.
// ignore_for_file: unnecessary_string_escapes

// Shared by every query that returns Media — AniList needs the fragment
// definition inlined in each query document that spreads it.
const mediaFields = '''
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
''';

// ── Live: used by client.ts for the real auth flow ──

const viewerQuery = '''
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
        # every custom list's name, empty ones too: the editor offers them
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
''';

const savedEntryFields = '''
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
''';

// Variables left out of the request are left unchanged on AniList, so
// saveEntry() only sends the fields being edited. `score` is in the viewer's
// own mediaListOptions.scoreFormat.
const saveEntryMutation =
    '''
  mutation SaveEntry(
    \$mediaId: Int
    \$status: MediaListStatus
    \$progress: Int
    \$progressVolumes: Int
    \$score: Float
    \$repeat: Int
    \$notes: String
    \$private: Boolean
    \$priority: Int
    \$startedAt: FuzzyDateInput
    \$completedAt: FuzzyDateInput
    \$customLists: [String]
  ) {
    SaveMediaListEntry(
      mediaId: \$mediaId
      status: \$status
      progress: \$progress
      progressVolumes: \$progressVolumes
      score: \$score
      repeat: \$repeat
      notes: \$notes
      private: \$private
      priority: \$priority
      startedAt: \$startedAt
      completedAt: \$completedAt
      customLists: \$customLists
    ) {
      $savedEntryFields
    }
  }
''';

const deleteEntryMutation = '''
  mutation DeleteEntry(\$id: Int) {
    DeleteMediaListEntry(id: \$id) {
      deleted
    }
  }
''';

// ── Live: used by client.ts fetchHomeData() for the real Home feed.
// Field set verified working against the real AniList API. `continueList`
// is the one addition beyond what was verified — `Viewer`/`User` has no
// `mediaList` field (confirmed by testing), so list entries have to come
// from the top-level `Page.mediaList(userId: ...)` field instead, same
// pattern as the other three Page fields below. ──

// ── Home: two queries so a failure only takes down its own section ──

/// The viewer's in-progress list (Continue + hero), and whether the list has anything at all.
const homeListQuery =
    '''
  query HomeList(\$userId: Int!, \$type: MediaType!, \$perPage: Int = 10) {
    continueList: Page(perPage: \$perPage) {
      mediaList(
        userId: \$userId
        type: \$type
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
        userId: \$userId
        type: \$type
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
      mediaList(userId: \$userId, type: \$type) {
        id
      }
    }
  }

  $mediaFields
''';

/// Trending / popular / upcoming rows. Each title carries the viewer's own
/// list entry (null when not on the list, or when signed out), so cards show
/// list state for every title — not just the ones in Continue.
///
const homeFeedQuery =
    '''
  query HomeFeed(
    \$type: MediaType!
    \$season: MediaSeason
    \$seasonYear: Int
    \$nextSeason: MediaSeason
    \$nextSeasonYear: Int
    \$perPage: Int = 10
  ) {
    trending: Page(perPage: \$perPage) {
      media(type: \$type, sort: TRENDING_DESC) {
        ...FeedMedia
      }
    }

    popularThisSeason: Page(perPage: \$perPage) {
      media(
        type: \$type
        season: \$season
        seasonYear: \$seasonYear
        status: RELEASING
        sort: POPULARITY_DESC
      ) {
        ...FeedMedia
      }
    }

    upcoming: Page(perPage: \$perPage) {
      media(
        type: \$type
        season: \$nextSeason
        seasonYear: \$nextSeasonYear
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

  $mediaFields
''';

/// First-run setup: how much was "imported" from the AniList account.
const viewerCountsQuery = '''
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
''';

/// Account settings miruyo follows — written back to AniList, the one source of truth.
const updateSettingsMutation = '''
  mutation UpdateSettings(
    \$titleLanguage: UserTitleLanguage
    \$displayAdultContent: Boolean
    \$airingNotifications: Boolean
    \$scoreFormat: ScoreFormat
  ) {
    UpdateUser(
      titleLanguage: \$titleLanguage
      displayAdultContent: \$displayAdultContent
      airingNotifications: \$airingNotifications
      scoreFormat: \$scoreFormat
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
''';

/// No Viewer/User field, so no auth token needed — used for the logged-out Home.
const publicTrendingQuery =
    '''
  query PublicTrending(\$type: MediaType!, \$perPage: Int = 16) {
    trending: Page(perPage: \$perPage) {
      media(type: \$type, sort: TRENDING_DESC) {
        ...MediaFields
      }
    }
  }

  $mediaFields
''';

// ── Browse ──

/// One page of Browse results. Every filter is optional: AniList ignores
/// null arguments. Variables are built by toQueryVariables() in browse/params.ts.
///
/// No `mediaListEntry` here: on this query AniList answers it with a 500
/// (signed in or not). The viewer's entries come from LIST_ENTRIES_QUERY.
///
const browseQuery =
    '''
  query Browse(
    \$page: Int = 1
    \$perPage: Int = 30
    \$type: MediaType!
    \$search: String
    \$genres: [String]
    \$tags: [String]
    \$notGenres: [String]
    \$notTags: [String]
    \$formats: [MediaFormat]
    \$status: MediaStatus
    \$season: MediaSeason
    \$seasonYear: Int
    \$country: CountryCode
    \$scoreAbove: Int
    \$scoreBelow: Int
    \$onList: Boolean
    \$isAdult: Boolean
    \$sort: [MediaSort]
  ) {
    Page(page: \$page, perPage: \$perPage) {
      pageInfo {
        total
        currentPage
        hasNextPage
      }
      media(
        type: \$type
        search: \$search
        genre_in: \$genres
        tag_in: \$tags
        genre_not_in: \$notGenres
        tag_not_in: \$notTags
        format_in: \$formats
        status: \$status
        season: \$season
        seasonYear: \$seasonYear
        countryOfOrigin: \$country
        averageScore_greater: \$scoreAbove
        averageScore_lesser: \$scoreBelow
        onList: \$onList
        isAdult: \$isAdult
        sort: \$sort
      ) {
        ...MediaFields
      }
    }
  }

  $mediaFields
''';

/// The viewer's list entries for specific titles — list state for Browse results.
const listEntriesQuery = '''
  query ListEntries(\$userId: Int!, \$ids: [Int], \$perPage: Int = 50) {
    Page(perPage: \$perPage) {
      mediaList(userId: \$userId, mediaId_in: \$ids) {
        id
        mediaId
        status
        progress
      }
    }
  }
''';

/// Every genre and tag AniList knows — for the filter rail. Changes rarely.
const browseCollectionsQuery = '''
  query BrowseCollections {
    GenreCollection
    MediaTagCollection {
      name
      category
      isAdult
    }
  }
''';

/// What else a Browse search matches: characters, staff and studios.
const searchPeopleQuery = '''
  query SearchPeople(\$search: String!, \$perPage: Int = 8) {
    characters: Page(perPage: \$perPage) {
      characters(search: \$search, sort: [SEARCH_MATCH, FAVOURITES_DESC]) {
        id
        name { userPreferred }
        image { large medium }
        media(perPage: 1, sort: [POPULARITY_DESC]) {
          nodes { title { userPreferred english romaji } }
        }
      }
    }
    staff: Page(perPage: \$perPage) {
      staff(search: \$search, sort: [SEARCH_MATCH, FAVOURITES_DESC]) {
        id
        name { userPreferred }
        image { large medium }
        primaryOccupations
      }
    }
    users: Page(perPage: \$perPage) {
      users(search: \$search, sort: [SEARCH_MATCH]) {
        id
        name
        avatar { large medium }
      }
    }
    studios: Page(perPage: 6) {
      studios(search: \$search, sort: [SEARCH_MATCH]) {
        id
        name
        siteUrl
        isAnimationStudio
      }
    }
  }
''';

// ── Title detail ──

/// A title's Stats tab: how AniList's users score it and where it sits on
/// their lists, and its rankings. Loaded when the tab opens, so the page's
/// first load stays as it was. Public: sent without a token.
const titleStatsQuery = '''
  query TitleStats(\$id: Int!) {
    Media(id: \$id) {
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
''';

/// Everything the title page shows. Checked against the live API (signed
/// out) before use — see BROWSE_QUERY for why. `mediaListEntry` and
/// `isFavourite` are only meaningful with a token (null / false without).
///
const detailQuery =
    '''
  query Detail(\$id: Int!) {
    Media(id: \$id) {
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
        $savedEntryFields
      }
    }
  }

  $mediaFields
''';

/// One list entry, for the editor when it's opened from a card.
const entryQuery =
    '''
  query Entry(\$userId: Int!, \$mediaId: Int!) {
    MediaList(userId: \$userId, mediaId: \$mediaId) {
      $savedEntryFields
    }
  }
''';

const toggleFavouriteMutation = '''
  mutation ToggleFavourite(
    \$animeId: Int
    \$mangaId: Int
    \$characterId: Int
    \$staffId: Int
    \$studioId: Int
  ) {
    ToggleFavourite(
      animeId: \$animeId
      mangaId: \$mangaId
      characterId: \$characterId
      staffId: \$staffId
      studioId: \$studioId
    ) {
      anime(perPage: 1) {
        pageInfo {
          total
        }
      }
    }
  }
''';

// ── My List ──

/// The fields a list row needs — lighter than MEDIA_FIELDS (no description or
/// banner), since a list can hold thousands of titles.
///
const listMediaFields = '''
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
''';

/// The viewer's whole list for one type, grouped by status and custom list.
const listCollectionQuery =
    '''
  query ListCollection(\$userId: Int!, \$type: MediaType!) {
    MediaListCollection(userId: \$userId, type: \$type) {
      lists {
        name
        status
        isCustomList
        entries {
          $savedEntryFields
          updatedAt
          media {
            ...ListMedia
          }
        }
      }
    }
  }

  $listMediaFields
''';

// ── Seasonal ──

/// Every episode airing in a time window, soonest first — a week is ~100-150
/// airings, so this is paged (50 at a time). List state comes separately
/// (loadListState), as with Browse.
///
const airingWeekQuery =
    '''
  query AiringWeek(\$start: Int!, \$end: Int!, \$page: Int = 1) {
    Page(page: \$page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      airingSchedules(airingAt_greater: \$start, airingAt_lesser: \$end, sort: TIME) {
        id
        episode
        airingAt
        media {
          ...ListMedia
        }
      }
    }
  }

  $listMediaFields
''';

/// Manga for "New releases": AniList has no per-chapter release data, so this
/// is popular series that started serializing recently and are still running.
///
const newMangaQuery =
    '''
  query NewManga(\$since: FuzzyDateInt, \$perPage: Int = 24, \$isAdult: Boolean) {
    Page(perPage: \$perPage) {
      media(
        type: MANGA
        status: RELEASING
        startDate_greater: \$since
        sort: POPULARITY_DESC
        isAdult: \$isAdult
      ) {
        ...ListMedia
      }
    }
  }

  $listMediaFields
''';

// ── Stats ──

/// Daily list activity for the Stats heatmap. AniList keeps about six months
/// and doesn't split it by anime and manga. (The rest of Stats is computed
/// from LIST_COLLECTION_QUERY: User.statistics' breakdowns are often stale.)
///
const activityHistoryQuery = '''
  query ActivityHistory(\$userId: Int!) {
    User(id: \$userId) {
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
''';

// ── Season chart ──

/// A season-chart card: the full media fields plus source, start, ranks and prequel.
const seasonMediaFields =
    '''
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

  $mediaFields
''';

/// Everything premiering in a season, most popular first (~100 titles, 2 pages).
const seasonChartQuery =
    '''
  query SeasonChart(\$season: MediaSeason!, \$year: Int!, \$page: Int = 1, \$isAdult: Boolean) {
    Page(page: \$page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      media(
        type: ANIME
        season: \$season
        seasonYear: \$year
        sort: POPULARITY_DESC
        isAdult: \$isAdult
      ) {
        ...SeasonMedia
      }
    }
  }

  $seasonMediaFields
''';

/// "Leftovers": AniList has no such filter, so this takes a week of airings
/// (the season's second, after last season's finales) and the caller keeps
/// the shows that started before the season.
///
const seasonLeftoversQuery =
    '''
  query SeasonLeftovers(\$start: Int!, \$end: Int!, \$page: Int = 1) {
    Page(page: \$page, perPage: 50) {
      pageInfo {
        hasNextPage
      }
      airingSchedules(airingAt_greater: \$start, airingAt_lesser: \$end, sort: TIME) {
        media {
          ...SeasonMedia
        }
      }
    }
  }

  $seasonMediaFields
''';

const notificationUser = '''user { id name avatar { medium } }''';
const notificationMedia = '''media { id type title { userPreferred } coverImage { medium } }''';
const notificationThread = '''thread { id title }''';

/// The viewer's latest notifications, newest first. Fetching them marks them
/// read on AniList (`resetNotificationCount`), as opening AniList's own page does.
///
const notificationsQuery =
    '''
  query Notifications(\$perPage: Int) {
    Page(page: 1, perPage: \$perPage) {
      notifications(resetNotificationCount: true) {
        __typename
        ... on AiringNotification { id createdAt episode contexts $notificationMedia }
        ... on FollowingNotification { id createdAt context $notificationUser }
        ... on ActivityMessageNotification { id createdAt context activityId $notificationUser }
        ... on ActivityMentionNotification { id createdAt context activityId $notificationUser }
        ... on ActivityReplyNotification { id createdAt context activityId $notificationUser }
        ... on ActivityReplySubscribedNotification { id createdAt context activityId $notificationUser }
        ... on ActivityLikeNotification { id createdAt context activityId $notificationUser }
        ... on ActivityReplyLikeNotification { id createdAt context activityId $notificationUser }
        ... on ThreadCommentMentionNotification { id createdAt context commentId $notificationThread $notificationUser }
        ... on ThreadCommentReplyNotification { id createdAt context commentId $notificationThread $notificationUser }
        ... on ThreadCommentSubscribedNotification { id createdAt context commentId $notificationThread $notificationUser }
        ... on ThreadCommentLikeNotification { id createdAt context commentId $notificationThread $notificationUser }
        ... on ThreadLikeNotification { id createdAt context $notificationThread $notificationUser }
        ... on RelatedMediaAdditionNotification { id createdAt context $notificationMedia }
        ... on MediaDataChangeNotification { id createdAt context $notificationMedia }
        ... on MediaMergeNotification { id createdAt context deletedMediaTitles $notificationMedia }
        ... on MediaDeletionNotification { id createdAt context deletedMediaTitle }
      }
    }
  }
''';

/// Just the unread count, to refresh the bell without refetching the viewer.
const unreadCountQuery = '''
  query UnreadCount {
    Viewer {
      id
      unreadNotificationCount
    }
  }
''';

const profilePeople = '''nodes { id name { userPreferred } image { large medium } siteUrl }''';

/// A profile's favourites. Titles come back as ids only: asked through
/// favourites, AniList answered every title with an Internal Server Error
/// (one per title, on the live API), so favouriteMediaQuery fetches them
/// directly, as the rest of the app does.
const _profileFavourites =
    '''
  favourites {
    anime(page: 1, perPage: \$perPage) { nodes { id } }
    manga(page: 1, perPage: \$perPage) { nodes { id } }
    characters(page: 1, perPage: \$peoplePerPage) { $profilePeople }
    staff(page: 1, perPage: \$peoplePerPage) { $profilePeople }
    studios(page: 1, perPage: \$peoplePerPage) { nodes { id name siteUrl } }
  }
''';

/// Someone's profile (yours included), by name (AniList matches it whatever the case).
const userProfileQuery =
    '''
  query UserProfile(\$name: String!, \$perPage: Int = 7, \$peoplePerPage: Int = 10) {
    User(name: \$name) {
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
      $_profileFavourites
    }
  }
''';

const toggleFollowMutation = '''
  mutation ToggleFollow(\$userId: Int!) {
    ToggleFollow(userId: \$userId) {
      id
      isFollowing
    }
  }
''';

/// Favourite titles by id (anime and manga together).
const favouriteMediaQuery =
    '''
  query FavouriteMedia(\$ids: [Int]) {
    Page(perPage: 50) {
      media(id_in: \$ids) {
        ...ListMedia
        mediaListEntry {
          id
          status
          progress
        }
      }
    }
  }

  $listMediaFields
''';

/// For You: AniList's recommendations for each seed, one aliased Media(id:)
/// per seed (the shape the title page's "If you like this" already uses).
/// Seed ids are integers from the viewer's own list.
/// For You's cross-mode picks: the related titles of a few titles you loved
/// on your other list, read for their source (an anime's manga) or
/// adaptations (a manga's anime). Copied from the web's
/// forYouRelationsQuery.
String forYouRelationsQuery(List<int> seedIds) {
  final seeds = [
    for (final (i, id) in seedIds.indexed)
      '''
    s$i: Media(id: $id) {
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
    }''',
  ].join();
  return '''
  query ForYouRelations {$seeds
  }

  $listMediaFields
''';
}

String forYouQuery(List<int> seedIds, {int perSeed = 8}) {
  final seeds = [
    for (final (i, id) in seedIds.indexed)
      '''
    s$i: Media(id: $id) {
      id
      recommendations(perPage: $perSeed, sort: [RATING_DESC]) {
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
    }''',
  ].join();
  return '''
  query ForYou {$seeds
  }

  $listMediaFields
''';
}

// ── People: staff and characters ──

const _personMedia = '''
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
''';

const _personName = '''
  name {
    full
    native
    userPreferred
    alternative
  }
''';

const _staffVoiceRoles =
    '''
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
      $_personMedia
    }
  }
''';

const _staffCredits =
    '''
  pageInfo {
    total
    hasNextPage
  }
  edges {
    staffRole
    node {
      $_personMedia
    }
  }
''';

// AniList returns at most 25 of a person's roles a page, whatever's asked for

/// A staff page: who they are, then the first page of their voice roles and credits.
const staffPageQuery =
    '''
  query StaffPage(\$id: Int!, \$sort: [MediaSort], \$perPage: Int = 25) {
    Staff(id: \$id) {
      id
      $_personName
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
      characterMedia(page: 1, perPage: \$perPage, sort: \$sort) {
        $_staffVoiceRoles
      }
      staffMedia(page: 1, perPage: \$perPage, sort: \$sort) {
        $_staffCredits
      }
    }
  }
''';

/// More of a voice actor's roles ("Load more").
const staffVoiceRolesQuery =
    '''
  query StaffVoiceRoles(\$id: Int!, \$page: Int!, \$sort: [MediaSort], \$perPage: Int = 25) {
    Staff(id: \$id) {
      id
      characterMedia(page: \$page, perPage: \$perPage, sort: \$sort) {
        $_staffVoiceRoles
      }
    }
  }
''';

const _studioMedia =
    '''
  pageInfo {
    total
    hasNextPage
  }
  edges {
    isMainStudio
    node {
      $_personMedia
    }
  }
''';

/// A studio page: the studio, then the first page of its titles. Copied
/// from the web's STUDIO_PAGE_QUERY.
const studioPageQuery =
    '''
  query StudioPage(\$id: Int!, \$sort: [MediaSort], \$perPage: Int = 25) {
    Studio(id: \$id) {
      id
      name
      isAnimationStudio
      siteUrl
      favourites
      isFavourite
      media(page: 1, perPage: \$perPage, sort: \$sort) {
        $_studioMedia
      }
    }
  }
''';

/// More of a studio's titles ("Load more").
const studioMediaQuery =
    '''
  query StudioMedia(\$id: Int!, \$page: Int!, \$sort: [MediaSort], \$perPage: Int = 25) {
    Studio(id: \$id) {
      id
      media(page: \$page, perPage: \$perPage, sort: \$sort) {
        $_studioMedia
      }
    }
  }
''';

/// More of someone's production credits ("Load more").
const staffCreditsQuery =
    '''
  query StaffCredits(\$id: Int!, \$page: Int!, \$sort: [MediaSort], \$perPage: Int = 25) {
    Staff(id: \$id) {
      id
      staffMedia(page: \$page, perPage: \$perPage, sort: \$sort) {
        $_staffCredits
      }
    }
  }
''';

const _characterAppearances =
    '''
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
      $_personMedia
    }
  }
''';

/// A character page: who they are, then the first page of the titles they're in.
const characterPageQuery =
    '''
  query CharacterPage(\$id: Int!, \$perPage: Int = 25) {
    Character(id: \$id) {
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
      media(page: 1, perPage: \$perPage, sort: [POPULARITY_DESC]) {
        $_characterAppearances
      }
    }
  }
''';

/// More of the titles a character is in ("Load more").
const characterAppearancesQuery =
    '''
  query CharacterAppearances(\$id: Int!, \$page: Int!, \$perPage: Int = 25) {
    Character(id: \$id) {
      id
      media(page: \$page, perPage: \$perPage, sort: [POPULARITY_DESC]) {
        $_characterAppearances
      }
    }
  }
''';

/// Someone else's list, as anyone sees it (private entries left out). Scores
/// come on one scale (10 with decimals) whoever's asking, so their stats and
/// scores read the same for every viewer.
const userListQuery =
    '''
  query UserList(\$userId: Int!, \$type: MediaType!) {
    MediaListCollection(userId: \$userId, type: \$type) {
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

  $listMediaFields
''';
