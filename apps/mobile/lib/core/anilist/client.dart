// The AniList GraphQL client, ported from apps/web/src/lib/anilist/client.ts:
// the same error kinds, request cache and calls. Native differences: real
// 429 headers are readable (the browser hides them behind CORS), and a
// response store keeps the last copy of chosen queries for offline use.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../catalog/season.dart';
import 'errors.dart';
import 'pacer.dart';
import 'queries.dart';
import 'types.dart';

const anilistEndpoint = 'https://graphql.anilist.co';

/// Used when a 429 doesn't say how long to wait. AniList's window is a minute.
const defaultRetryAfter = 60;

/// How long a successful response is reused.
const cacheTtl = Duration(seconds: 60);

/// AniList's wording for a token it no longer accepts (sent with a 400).
final _invalidToken = RegExp('invalid token', caseSensitive: false);

/// Where persisted responses live between launches (the drift kv_cache).
abstract interface class ResponseStore {
  Future<({Json data, DateTime savedAt})?> read(String key);
  Future<void> write(String key, Json data);
  Future<void> clear();
}

/// A response that may have come from the device instead of AniList.
class Fetched<T> {
  const Fetched(this.data, {this.savedAt, this.fromDevice = false, this.stamp = 0});

  final T data;

  /// The list store's stamp() when this copy was requested (see
  /// [AniListClient.requestStamp]); 0, older than every edit, when unknown.
  final int stamp;

  /// When the copy was saved; set when [fromDevice].
  final DateTime? savedAt;

  /// AniList couldn't be reached, so this is the last copy kept on the device.
  final bool fromDevice;

  Fetched<R> map<R>(R Function(T) f) => Fetched(f(data), savedAt: savedAt, fromDevice: fromDevice, stamp: stamp);
}

/// A response [AniListClient.cachedQuery] replaced in the background.
typedef Refreshed = ({String document, Json variables});

/// Whether [r] is the list query for [userId]'s [type] list.
bool isListRefresh(Refreshed r, String document, int userId, MediaType type) =>
    r.document == document && r.variables['userId'] == userId && r.variables['type'] == type.api;

class _CacheEntry {
  _CacheEntry(this.future, this.token, {this.swr = false, this.persistAs});

  Future<Json> future;

  /// The token the request was sent with ('' for public requests).
  final String token;

  /// null while in flight; the epoch once a list edit made it stale.
  DateTime? expires;

  /// Served stale while a newer copy loads (staleWhileRevalidate).
  final bool swr;

  /// The device copy's key, when a newer copy should be saved there too.
  final String? persistAs;

  /// The background request replacing it, if one is running.
  Future<Json>? refresh;
}

/// Fields of a list entry that can be saved. Omitted (null) fields are left
/// as they are on AniList.
class EntryInput {
  const EntryInput({
    this.status,
    this.progress,
    this.progressVolumes,
    this.score,
    this.startedAt,
    this.completedAt,
    this.repeat,
    this.notes,
    this.private,
    this.priority,
    this.customLists,
  });

  factory EntryInput.fromJson(Json j) => EntryInput(
    status: j['status'] == null ? null : MediaListStatus.parse(j['status']),
    progress: j['progress'] as int?,
    progressVolumes: j['progressVolumes'] as int?,
    score: (j['score'] as num?)?.toDouble(),
    startedAt: j['startedAt'] == null ? null : AniListDate.fromJson(j['startedAt'] as Json),
    completedAt: j['completedAt'] == null ? null : AniListDate.fromJson(j['completedAt'] as Json),
    repeat: j['repeat'] as int?,
    notes: j['notes'] as String?,
    private: j['private'] as bool?,
    priority: j['priority'] as int?,
    customLists: switch (j['customLists']) {
      final List names => [...names.whereType<String>()],
      _ => null,
    },
  );

  final MediaListStatus? status;
  final int? progress;
  final int? progressVolumes;

  /// In the viewer's own scoreFormat. 0 clears it.
  final double? score;

  /// Pass [AniListDate.empty] to clear a date.
  final AniListDate? startedAt;
  final AniListDate? completedAt;
  final int? repeat;
  final String? notes;
  final bool? private;

  /// Up next order on Planning: higher comes first.
  final int? priority;

  /// The names of every custom list it should be on (the whole set, not a change).
  final List<String>? customLists;

  bool get isEmpty => toJson().isEmpty;

  /// Only the fields being changed, as SaveMediaListEntry variables.
  Json toJson() => {
    if (status != null) 'status': status!.api,
    if (progress != null) 'progress': progress,
    if (progressVolumes != null) 'progressVolumes': progressVolumes,
    if (score != null) 'score': score,
    if (startedAt != null) 'startedAt': startedAt!.toJson(),
    if (completedAt != null) 'completedAt': completedAt!.toJson(),
    if (repeat != null) 'repeat': repeat,
    if (notes != null) 'notes': notes,
    if (private != null) 'private': private,
    if (priority != null) 'priority': priority,
    if (customLists != null) 'customLists': customLists,
  };

  /// This input with [later]'s fields on top: two queued edits become one.
  EntryInput merge(EntryInput later) => EntryInput.fromJson({...toJson(), ...later.toJson()});
}

class ViewerSettings {
  const ViewerSettings({this.titleLanguage, this.displayAdultContent, this.airingNotifications, this.scoreFormat});

  final TitleLanguage? titleLanguage;
  final bool? displayAdultContent;
  final bool? airingNotifications;
  final ScoreFormat? scoreFormat;

  Json toJson() => {
    if (titleLanguage != null) 'titleLanguage': titleLanguage!.api,
    if (displayAdultContent != null) 'displayAdultContent': displayAdultContent,
    if (airingNotifications != null) 'airingNotifications': airingNotifications,
    if (scoreFormat != null) 'scoreFormat': scoreFormat!.api,
  };
}

class AniListClient {
  AniListClient({http.Client? httpClient, this.store, DateTime Function()? now, Pacer? pacer})
    : _http = httpClient ?? http.Client(),
      _now = now ?? DateTime.now,
      pacer = pacer ?? Pacer(now: now);

  final http.Client _http;
  final DateTime Function() _now;
  final ResponseStore? store;

  /// The signed-in viewer's token; null when signed out.
  String? token;

  /// Called whenever AniList rejects the stored token. The session signs out.
  void Function()? onUnauthorized;

  /// Spaces requests out as the minute's budget runs low (pacer.dart).
  final Pacer pacer;

  final _cache = <String, _CacheEntry>{};

  /// Sends one request. [authToken]: omit to use [token], pass '' to send it
  /// without one (public queries).
  Future<Json> query(String document, {Json variables = const {}, String? authToken}) async {
    final sent = authToken ?? token;
    final hasToken = sent != null && sent.isNotEmpty;

    await pacer.slot();
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse(anilistEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (hasToken) 'Authorization': 'Bearer $sent',
            },
            body: jsonEncode({'query': document, 'variables': variables}),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      pacer.settle(null);
      throw AniListError(e.message, AniListErrorKind.network);
    } on TimeoutException {
      pacer.settle(null);
      throw const AniListError('AniList took too long to answer.', AniListErrorKind.network);
    } on http.ClientException catch (e) {
      pacer.settle(null);
      throw AniListError(e.message, AniListErrorKind.network);
    }

    pacer.settle(res.headers);
    final remaining = pacer.left;
    if (kDebugMode) {
      // one line per request, to keep an eye on the 30-a-minute budget
      final name = RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(document)?.group(1) ?? '?';
      debugPrint('anilist: $name ${res.statusCode} (left this minute: ${remaining ?? '?'})');
    }

    // AniList returns a JSON body with real error detail even on 4xx/5xx;
    // parse it before giving up instead of reporting a bare status
    Json? json;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Json) json = decoded;
    } on FormatException {
      // a non-JSON body (e.g. a plain-text 5xx from a proxy)
    }

    final errors = [
      for (final e in (json?['errors'] as List?) ?? const [])
        if (e is Json) e,
    ];
    final message = errors.isNotEmpty
        ? errors.map((e) => e['message']).join('; ')
        : 'AniList request failed with status ${res.statusCode}.';

    if (res.statusCode == 429 || errors.any((e) => e['status'] == 429)) {
      final wait = _retryAfterSeconds(res);
      pacer.pause(wait);
      throw AniListError(message, AniListErrorKind.rateLimit, status: 429, retryAfter: wait);
    }

    // A bad token comes back as a 400 with "Invalid token" as often as a
    // 401, so check both. Other permission errors are about that request,
    // not the token, and must not sign the viewer out.
    if (hasToken &&
        (res.statusCode == 401 ||
            errors.any((e) => e['status'] == 401 || _invalidToken.hasMatch('${e['message'] ?? ''}')))) {
      onUnauthorized?.call();
      throw AniListError(message, AniListErrorKind.unauthorized, status: 401);
    }

    if (errors.isNotEmpty || res.statusCode >= 400) {
      throw AniListError(message, AniListErrorKind.api, status: res.statusCode);
    }

    final data = json?['data'];
    if (data is! Json) {
      throw AniListError('No data returned from AniList API.', AniListErrorKind.api, status: res.statusCode);
    }
    return data;
  }

  /// Seconds to wait, from Retry-After or (failing that) X-RateLimit-Reset.
  int _retryAfterSeconds(http.Response res) {
    final retryAfter = num.tryParse(res.headers['retry-after'] ?? '');
    if (retryAfter != null && retryAfter > 0) return retryAfter.ceil();
    final reset = num.tryParse(res.headers['x-ratelimit-reset'] ?? '');
    if (reset != null && reset > 0) {
      final seconds = (reset - _now().millisecondsSinceEpoch / 1000).ceil();
      if (seconds > 0) return seconds;
    }
    return defaultRetryAfter;
  }

  // ── Request cache ──
  // AniList allows ~90 requests a minute (sometimes cut to 30), so identical
  // queries share one in-flight request and reuse the result for a while
  // (and the pacer spaces requests out as the limit nears).

  /// Drops every cached response. Called on sign-in and sign-out.
  void clearCache() => _cache.clear();

  /// Drops the responses fetched with a token. Called after a list edit,
  /// since those carry list state; public responses stay cached. A list
  /// collection is kept but marked stale: it's served while a newer one loads.
  /// [lists]: drop those too (pull to refresh waits for a new copy).
  void clearViewerCache({bool lists = false}) {
    _cache.removeWhere((_, e) => e.token.isNotEmpty && (lists || !e.swr));
    for (final e in _cache.values) {
      if (e.token.isNotEmpty && e.expires != null) e.expires = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  // ── Stale lists and local edits ──
  // A list collection is large (seconds to load for a long list), so once it
  // has loaded it's served at once, even past its TTL or after an edit, while
  // a newer copy loads behind it. A copy can then predate a local edit: each
  // response remembers the edit clock (the list store's stamp()) from when it
  // was requested, and whoever seeds the store from it passes that on, so a
  // stale copy never undoes an edit.

  /// The list store's stamp(), read when each request starts.
  int Function() editClock = () => 0;

  final _stamps = Expando<int>();

  /// Responses already written to the device copy.
  final _saved = Expando<bool>();

  /// The edit clock when [data] was requested, for ListStore.seed(). Unknown
  /// data counts as older than every edit, which keeps every local value.
  int requestStamp(Json data) => _stamps[data] ?? 0;

  final _refreshed = StreamController<Refreshed>.broadcast();

  /// Fires when a stale response has been replaced in the background: which
  /// query, with which variables, so only what shows it builds again.
  Stream<Refreshed> get refreshed => _refreshed.stream;

  String _key(String? sent, String document, Json variables) => jsonEncode([sent ?? '', document, variables]);

  /// [staleWhileRevalidate]: once loaded, serve the last response at once,
  /// even when expired or made stale by an edit, and load a newer one behind
  /// it ([refreshed] says when; [persistAs] saves it on the device too).
  /// [fresh]: wait for a new response (pull to refresh, a Retry).
  Future<Json> cachedQuery(
    String document, {
    Json variables = const {},
    String? authToken,
    Duration ttl = cacheTtl,
    bool staleWhileRevalidate = false,
    bool fresh = false,
    String? persistAs,
  }) {
    final sent = authToken ?? token;
    // the token is part of the key: the same query returns different data
    // (list state, preferred titles) for different viewers
    final key = _key(sent, document, variables);

    final hit = _cache[key];
    if (hit != null && hit.expires == null) return hit.future;
    if (hit != null && hit.expires!.isAfter(_now()) && !fresh) return hit.future;
    if (hit != null && hit.swr) {
      final refresh = hit.refresh ??= _revalidate(key, hit, document, variables, authToken, ttl);
      return fresh ? refresh : hit.future;
    }

    late final _CacheEntry entry;
    final stamp = editClock();
    final future = query(document, variables: variables, authToken: authToken).then(
      (data) {
        _stamps[data] = stamp;
        // an edit while it loaded: it's already stale
        if (identical(_cache[key], entry)) {
          entry.expires = stamp < editClock() ? DateTime.fromMillisecondsSinceEpoch(0) : _now().add(ttl);
        }
        return data;
      },
      onError: (Object err, StackTrace st) {
        if (identical(_cache[key], entry)) _cache.remove(key);
        Error.throwWithStackTrace(err, st);
      },
    );
    entry = _CacheEntry(future, sent ?? '', swr: staleWhileRevalidate, persistAs: persistAs);
    _cache[key] = entry;
    return future;
  }

  /// Loads a newer copy of a stale entry and swaps it in. A failure keeps the
  /// stale copy (the next read tries again) and only reaches a [fresh] read.
  Future<Json> _revalidate(
    String key,
    _CacheEntry entry,
    String document,
    Json variables,
    String? authToken,
    Duration ttl,
  ) {
    final stamp = editClock();
    final refresh = query(document, variables: variables, authToken: authToken).then(
      (data) async {
        // signed out (or replaced) meanwhile: leave the cache alone
        if (!identical(_cache[key], entry)) return data;
        _stamps[data] = stamp;
        entry
          ..future = Future.value(data)
          ..expires = stamp < editClock() ? DateTime.fromMillisecondsSinceEpoch(0) : _now().add(ttl)
          ..refresh = null;
        // first: a slow or failed device write mustn't hold the screens back
        _refreshed.add((document: document, variables: variables));
        if (entry.persistAs case final saveAs?) {
          await store?.write(saveAs, data);
          _saved[data] = true;
        }
        return data;
      },
      onError: (Object err, StackTrace st) {
        if (identical(_cache[key], entry)) entry.refresh = null;
        Error.throwWithStackTrace(err, st);
      },
    );
    // nobody may be waiting on it
    unawaited(refresh.then((_) {}, onError: (Object _) {}));
    return refresh;
  }

  /// [cachedQuery], keeping the last good response on the device: when
  /// AniList can't be reached, that copy comes back instead (marked
  /// [Fetched.fromDevice]). Only for viewer data the app must show offline.
  Future<Fetched<Json>> persistedQuery(
    String name,
    String document, {
    Json variables = const {},
    bool staleWhileRevalidate = false,
    bool fresh = false,
  }) async {
    final key = '$name:${jsonEncode(variables)}';
    try {
      final data = await cachedQuery(
        document,
        variables: variables,
        staleWhileRevalidate: staleWhileRevalidate,
        fresh: fresh,
        persistAs: staleWhileRevalidate ? key : null,
      );
      // once per response: a cached one has been saved already
      if (_saved[data] != true) {
        await store?.write(key, data);
        _saved[data] = true;
      }
      return Fetched(data, stamp: requestStamp(data));
    } on AniListError catch (e) {
      if (!e.isNetwork) rethrow;
      final saved = await store?.read(key);
      if (saved == null) rethrow;
      return Fetched(saved.data, savedAt: saved.savedAt, fromDevice: true);
    }
  }

  // ── Viewer ──

  Future<AniListUser> fetchViewer() async {
    final data = await query(viewerQuery);
    return AniListUser.fromJson(data['Viewer'] as Json);
  }

  /// How many anime and manga are on the viewer's list (first-run setup).
  Future<({int anime, int manga})> fetchViewerCounts() async {
    final data = await query(viewerCountsQuery);
    final stats = (data['Viewer'] as Json)['statistics'] as Json?;
    int count(String k) => ((stats?[k] as Json?)?['count'] as num?)?.toInt() ?? 0;
    return (anime: count('anime'), manga: count('manga'));
  }

  /// Saves account settings on AniList itself: miruyo follows the account's
  /// settings rather than keeping its own copy.
  Future<AniListUser> updateViewerSettings(ViewerSettings settings) async {
    final data = await query(updateSettingsMutation, variables: settings.toJson());
    // the list's scores come in the viewer's score format: an old copy is wrong
    clearViewerCache(lists: true);
    return AniListUser.fromJson(data['UpdateUser'] as Json);
  }

  Future<int> fetchUnreadCount() async {
    final data = await query(unreadCountQuery);
    return ((data['Viewer'] as Json)['unreadNotificationCount'] as num?)?.toInt() ?? 0;
  }

  /// The viewer's latest notifications, newest first. Marks them read on AniList.
  Future<List<Json>> fetchNotifications({int perPage = 25}) async {
    final data = await query(notificationsQuery, variables: {'perPage': perPage});
    return [
      for (final n in ((data['Page'] as Json)['notifications'] as List?) ?? const [])
        if (n is Json) n,
    ];
  }

  // ── List editing ──

  Future<AniListSavedEntry> saveEntry(int mediaId, EntryInput input) async {
    final data = await query(saveEntryMutation, variables: {'mediaId': mediaId, ...input.toJson()});
    clearViewerCache();
    return AniListSavedEntry.fromJson(data['SaveMediaListEntry'] as Json);
  }

  /// [entryId] is the list entry's own id, not the media id.
  Future<bool> deleteEntry(int entryId) async {
    final data = await query(deleteEntryMutation, variables: {'id': entryId});
    clearViewerCache();
    return (data['DeleteMediaListEntry'] as Json?)?['deleted'] == true;
  }

  /// The viewer's full entry for a title, or null when it isn't on their list.
  Future<AniListSavedEntry?> fetchEntry(int userId, int mediaId) async {
    try {
      final data = await query(entryQuery, variables: {'userId': userId, 'mediaId': mediaId});
      final entry = data['MediaList'] as Json?;
      return entry == null ? null : AniListSavedEntry.fromJson(entry);
    } on AniListError catch (e) {
      // AniList answers "not on the list" with a 404
      if (e.kind == AniListErrorKind.api && e.status == 404) return null;
      rethrow;
    }
  }

  /// Favourites (or un-favourites) a title, character or staff member on
  /// the viewer's profile.
  Future<void> toggleFavourite(FavouriteKind kind, int id) async {
    await query(toggleFavouriteMutation, variables: {kind.variable: id});
    clearViewerCache();
  }

  /// The viewer's whole list for one type, kept on the device for offline
  /// use. A title appears once: status lists first, then what custom lists
  /// alone hold (an entry set to "hide from status lists" on AniList is in a
  /// custom list only).
  Future<Fetched<List<CollectionEntry>>> fetchListCollection(int userId, MediaType type, {bool fresh = false}) async {
    final fetched = await _listCollection(userId, type, fresh: fresh);
    return fetched.map((data) {
      final seen = <int>{};
      final entries = <CollectionEntry>[];
      final lists = [..._listGroups(data)]
        ..sort((a, b) => (a['isCustomList'] == true ? 1 : 0) - (b['isCustomList'] == true ? 1 : 0));
      for (final group in lists) {
        for (final e in (group['entries'] as List? ?? const []).whereType<Json>()) {
          final entry = CollectionEntry.fromJson(e);
          if (seen.add(entry.entry.mediaId)) entries.add(entry);
        }
      }
      return entries;
    });
  }

  /// The viewer's custom lists, in AniList's order, and the titles that are
  /// only on them (set to "hide from status lists"). The same request (and
  /// cache) as [fetchListCollection], so asking for both costs one.
  Future<({List<CustomList> lists, Set<int> hidden})> fetchCustomLists(
    int userId,
    MediaType type, {
    bool fresh = false,
  }) async {
    final groups = _listGroups((await _listCollection(userId, type, fresh: fresh)).data);
    List<int> ids(Json group) => [
      for (final e in (group['entries'] as List? ?? const []).whereType<Json>()) (e['mediaId'] as num).toInt(),
    ];
    final onStatus = {
      for (final g in groups)
        if (g['isCustomList'] != true) ...ids(g),
    };
    final lists = [
      for (final g in groups)
        if (g['isCustomList'] == true && ids(g).isNotEmpty)
          CustomList(name: g['name'] as String? ?? '', mediaIds: ids(g)),
    ];
    final hidden = {
      for (final l in lists)
        for (final id in l.mediaIds)
          if (!onStatus.contains(id)) id,
    };
    return (lists: lists, hidden: hidden);
  }

  /// Served at once once loaded, refreshed behind (see staleWhileRevalidate).
  Future<Fetched<Json>> _listCollection(int userId, MediaType type, {bool fresh = false}) => persistedQuery(
    'list',
    listCollectionQuery,
    variables: {'userId': userId, 'type': type.api},
    staleWhileRevalidate: true,
    fresh: fresh,
  );

  static List<Json> _listGroups(Json data) =>
      (((data['MediaListCollection'] as Json?)?['lists'] as List?) ?? const []).whereType<Json>().toList();

  /// The viewer's entries for these titles (those not on the list are left out).
  Future<List<AniListOwnEntry>> fetchListEntries(int userId, List<int> mediaIds) async {
    if (mediaIds.isEmpty) return const [];
    final data = await cachedQuery(
      listEntriesQuery,
      variables: {'userId': userId, 'ids': mediaIds, 'perPage': mediaIds.length.clamp(1, 50)},
    );
    return [
      for (final e in ((data['Page'] as Json)['mediaList'] as List? ?? const []).whereType<Json>())
        AniListOwnEntry.fromJson(e),
    ];
  }

  // ── Home ──

  /// The viewer's in-progress list (Continue + hero), kept for offline use.
  Future<Fetched<Json>> fetchHomeList(int userId, MediaType type) =>
      persistedQuery('home-list', homeListQuery, variables: {'userId': userId, 'type': type.api, 'perPage': 10});

  /// Home's trending / popular / upcoming rows, with the viewer's entry on each.
  Future<Fetched<Json>> fetchHomeFeed(MediaType type, {DateTime? now}) {
    // AniList's season data is unreliable for manga, so only anime is
    // constrained by season
    final isAnime = type == MediaType.anime;
    final current = currentSeason(now ?? _now());
    final next = nextSeason(current);
    // no isAdult: AniList applies the viewer's own displayAdultContent
    return persistedQuery(
      'home-feed',
      homeFeedQuery,
      variables: {
        'type': type.api,
        'season': isAnime ? current.season.api : null,
        'seasonYear': isAnime ? current.year : null,
        'nextSeason': isAnime ? next.season.api : null,
        'nextSeasonYear': isAnime ? next.year : null,
        'perPage': 10,
      },
    );
  }

  /// Public trending titles for the signed-out Home; no token sent.
  Future<List<AniListMedia>> fetchPublicTrending(MediaType type) async {
    final data = await cachedQuery(publicTrendingQuery, variables: {'type': type.api, 'perPage': 16}, authToken: '');
    return mediaList((data['trending'] as Json)['media']);
  }

  // ── Browse & detail ──

  /// One page of Browse results. Signed out, sent without a token.
  Future<({List<AniListMedia> media, bool hasNextPage, int total})> fetchBrowse(
    Json variables, {
    required bool signedIn,
  }) async {
    final data = await cachedQuery(browseQuery, variables: variables, authToken: signedIn ? null : '');
    final page = data['Page'] as Json;
    final info = page['pageInfo'] as Json? ?? const {};
    return (
      media: mediaList(page['media']),
      hasNextPage: info['hasNextPage'] == true,
      total: (info['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// All genres and tags, for the filter sheet. Public and rarely changing.
  Future<Json> fetchBrowseCollections() =>
      cachedQuery(browseCollectionsQuery, authToken: '', ttl: const Duration(hours: 24));

  /// Everything the title page shows, as AniList returned it.
  Future<Json> fetchDetail(int id, {required bool signedIn}) async {
    final data = await cachedQuery(detailQuery, variables: {'id': id}, authToken: signedIn ? null : '');
    return data['Media'] as Json;
  }

  /// A title's Stats tab: its score and status breakdowns and rankings.
  /// Public, so no token.
  Future<Json> fetchTitleStats(int id) async {
    final data = await cachedQuery(titleStatsQuery, variables: {'id': id}, authToken: '');
    return data['Media'] as Json;
  }

  // ── People: staff and characters ──

  /// The characters, staff and studios a Browse search also matches; the
  /// same for everyone, so sent without a token.
  Future<Json> fetchSearchPeople(String search) =>
      cachedQuery(searchPeopleQuery, variables: {'search': search}, authToken: '');

  /// A staff page: the person, then the first page of their voice roles and
  /// credits. Signed in, it carries the viewer's favourite state.
  Future<Json> fetchStaff(int id, {required bool signedIn, required PersonSort sort}) async {
    final data = await cachedQuery(
      staffPageQuery,
      variables: {
        'id': id,
        'sort': [sort.api],
      },
      authToken: signedIn ? null : '',
    );
    return data['Staff'] as Json;
  }

  /// A studio page: the studio, then the first page of its titles. Signed
  /// in, it carries the viewer's favourite state.
  Future<Json> fetchStudio(int id, {required bool signedIn, required PersonSort sort}) async {
    final data = await cachedQuery(
      studioPageQuery,
      variables: {
        'id': id,
        'sort': [sort.api],
      },
      authToken: signedIn ? null : '',
    );
    return data['Studio'] as Json;
  }

  /// Another page of a studio's titles; the same for everyone, so sent without a token.
  Future<Json> fetchStudioMedia(int id, int page, PersonSort sort) async {
    final data = await cachedQuery(
      studioMediaQuery,
      variables: {
        'id': id,
        'page': page,
        'sort': [sort.api],
      },
      authToken: '',
    );
    return (data['Studio'] as Json)['media'] as Json;
  }

  /// Another page of a voice actor's roles; the same for everyone, so sent without a token.
  Future<Json> fetchStaffVoiceRoles(int id, int page, PersonSort sort) async {
    final data = await cachedQuery(
      staffVoiceRolesQuery,
      variables: {
        'id': id,
        'page': page,
        'sort': [sort.api],
      },
      authToken: '',
    );
    return (data['Staff'] as Json)['characterMedia'] as Json;
  }

  /// Another page of someone's credits; sent without a token.
  Future<Json> fetchStaffCredits(int id, int page, PersonSort sort) async {
    final data = await cachedQuery(
      staffCreditsQuery,
      variables: {
        'id': id,
        'page': page,
        'sort': [sort.api],
      },
      authToken: '',
    );
    return (data['Staff'] as Json)['staffMedia'] as Json;
  }

  /// A character page: the character, then the first page of the titles
  /// they're in. Signed in, it carries the viewer's favourite state.
  Future<Json> fetchCharacter(int id, {required bool signedIn}) async {
    final data = await cachedQuery(characterPageQuery, variables: {'id': id}, authToken: signedIn ? null : '');
    return data['Character'] as Json;
  }

  /// Another page of the titles a character is in; sent without a token.
  Future<Json> fetchCharacterAppearances(int id, int page) async {
    final data = await cachedQuery(characterAppearancesQuery, variables: {'id': id, 'page': page}, authToken: '');
    return (data['Character'] as Json)['media'] as Json;
  }

  // ── Schedule & seasons ──

  /// Every episode airing between [start] and [end] (unix seconds), soonest
  /// first. 18+ titles are left out unless [showAdult].
  Future<List<AiringSlot>> fetchAiringWeek(
    int start,
    int end, {
    required bool signedIn,
    required bool showAdult,
  }) async {
    const maxPages = 8; // a guard; ~3 pages in practice
    final slots = <AiringSlot>[];
    for (var page = 1; page <= maxPages; page++) {
      final data = await cachedQuery(
        airingWeekQuery,
        variables: {'start': start, 'end': end, 'page': page},
        authToken: signedIn ? null : '',
      );
      final p = data['Page'] as Json;
      slots.addAll([for (final s in (p['airingSchedules'] as List).whereType<Json>()) AiringSlot.fromJson(s)]);
      if ((p['pageInfo'] as Json?)?['hasNextPage'] != true) break;
    }
    return showAdult ? slots : slots.where((s) => !s.media.isAdult).toList();
  }

  /// Popular manga that started serializing since [since] and are still running.
  Future<List<AniListMedia>> fetchNewManga(DateTime since, {required bool signedIn, required bool showAdult}) async {
    final fuzzy = since.year * 10000 + since.month * 100;
    final data = await cachedQuery(
      newMangaQuery,
      variables: {'since': fuzzy, 'perPage': 24, if (!showAdult) 'isAdult': false},
      authToken: signedIn ? null : '',
    );
    return mediaList((data['Page'] as Json)['media']);
  }

  /// A season's chart: everything premiering in it, plus the leftovers —
  /// shows from earlier seasons still airing in its second week.
  Future<({List<AniListMedia> media, List<AniListMedia> leftovers})> fetchSeasonChart(
    SeasonYear season, {
    required bool signedIn,
    required bool showAdult,
  }) async {
    const maxPages = 6;
    final auth = signedIn ? null : '';
    final media = <AniListMedia>[];
    for (var page = 1; page <= maxPages; page++) {
      final data = await cachedQuery(
        seasonChartQuery,
        variables: {'season': season.season.api, 'year': season.year, 'page': page, if (!showAdult) 'isAdult': false},
        authToken: auth,
      );
      final p = data['Page'] as Json;
      media.addAll(mediaList(p['media']));
      if ((p['pageInfo'] as Json?)?['hasNextPage'] != true) break;
    }

    final startMonth = seasonStartMonth[season.season]!;
    final seasonStart = DateTime(season.year, startMonth);
    final start = seasonStart.millisecondsSinceEpoch ~/ 1000 + 7 * 86400;
    final end = start + 7 * 86400;
    final inSeason = {for (final m in media) m.id};
    final startKey = season.year * 100 + startMonth;
    final leftovers = <int, AniListMedia>{};
    for (var page = 1; page <= maxPages; page++) {
      final data = await cachedQuery(
        seasonLeftoversQuery,
        variables: {'start': start, 'end': end, 'page': page},
        authToken: auth,
      );
      final p = data['Page'] as Json;
      for (final slot in (p['airingSchedules'] as List).whereType<Json>()) {
        final m = AniListMedia.fromJson(slot['media'] as Json);
        final startDate = AniListDate.fromJson(m.raw['startDate'] as Json?);
        final started = (startDate.year ?? 0) * 100 + (startDate.month ?? 0);
        if (inSeason.contains(m.id) || leftovers.containsKey(m.id) || started == 0 || started >= startKey) {
          continue;
        }
        if (m.isAdult && !showAdult) continue;
        leftovers[m.id] = m;
      }
      if ((p['pageInfo'] as Json?)?['hasNextPage'] != true) break;
    }
    return (media: media, leftovers: leftovers.values.toList());
  }

  // ── Profile & For You ──

  /// Someone's profile (yours included), by name, with up to 25 of each
  /// favourite. Signed in, it says whether you follow each other.
  Future<({Json account, List<AniListMedia>? anime, List<AniListMedia>? manga, String? titlesError})> fetchUserProfile(
    String name, {
    required bool signedIn,
  }) async {
    final account =
        (await cachedQuery(
              userProfileQuery,
              variables: {'name': name, 'perPage': 25, 'peoplePerPage': 25},
              authToken: signedIn ? null : '',
            ))['User']
            as Json;
    final favourites = account['favourites'] as Json?;
    List<int> ids(String k) => [
      for (final n in (((favourites?[k] as Json?)?['nodes'] as List?) ?? const []).whereType<Json>())
        (n['id'] as num).toInt(),
    ];
    final animeIds = ids('anime'), mangaIds = ids('manga');
    if (animeIds.isEmpty && mangaIds.isEmpty) {
      return (account: account, anime: <AniListMedia>[], manga: <AniListMedia>[], titlesError: null);
    }
    try {
      final data = await cachedQuery(
        favouriteMediaQuery,
        variables: {
          'ids': [...animeIds, ...mangaIds],
        },
      );
      final byId = {for (final m in mediaList((data['Page'] as Json)['media'])) m.id: m};
      // id_in doesn't keep the favourites' order, so put it back
      List<AniListMedia> inOrder(List<int> list) => [for (final id in list) ?byId[id]];
      return (account: account, anime: inOrder(animeIds), manga: inOrder(mangaIds), titlesError: null);
    } on AniListError catch (e) {
      if (e.isUnauthorized) rethrow;
      return (account: account, anime: null, manga: null, titlesError: e.message);
    }
  }

  /// Someone else's list as anyone sees it: no token, private entries left
  /// out, scores out of 10. A title appears once, as on your own list.
  Future<List<CollectionEntry>> fetchUserList(int userId, MediaType type, {bool fresh = false}) async {
    final data = await cachedQuery(
      userListQuery,
      variables: {'userId': userId, 'type': type.api},
      authToken: '',
      staleWhileRevalidate: true,
      fresh: fresh,
    );
    final seen = <int>{};
    final lists = [..._listGroups(data)]
      ..sort((a, b) => (a['isCustomList'] == true ? 1 : 0) - (b['isCustomList'] == true ? 1 : 0));
    return [
      for (final group in lists)
        for (final e in (group['entries'] as List? ?? const []).whereType<Json>())
          if (seen.add((e['mediaId'] as num).toInt())) CollectionEntry.fromJson(e),
    ];
  }

  /// Follows or unfollows someone; returns whether the viewer now follows them.
  Future<bool> toggleFollow(int userId) async {
    final data = await query(toggleFollowMutation, variables: {'userId': userId});
    clearViewerCache();
    return (data['ToggleFollow'] as Json?)?['isFollowing'] == true;
  }

  /// The viewer's daily list activity (about six months), for the heatmap.
  Future<List<({int date, int amount, int level})>> fetchActivityHistory(int userId) async {
    final data = await cachedQuery(activityHistoryQuery, variables: {'userId': userId});
    final days = (((data['User'] as Json?)?['stats'] as Json?)?['activityHistory'] as List?) ?? const [];
    return [
      for (final d in days.whereType<Json>())
        (
          date: (d['date'] as num).toInt(),
          amount: (d['amount'] as num?)?.toInt() ?? 0,
          level: (d['level'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// AniList's recommendations for each seed id, by seed id.
  Future<Map<int, List<({int rating, AniListMedia media})>>> fetchRecommendations(List<int> seedIds) async {
    final result = <int, List<({int rating, AniListMedia media})>>{};
    if (seedIds.isEmpty) return result;
    final data = await cachedQuery(forYouQuery(seedIds));
    for (final seed in data.values.whereType<Json>()) {
      final nodes = ((seed['recommendations'] as Json?)?['nodes'] as List?) ?? const [];
      result[(seed['id'] as num).toInt()] = [
        for (final n in nodes.whereType<Json>())
          if (n['mediaRecommendation'] is Json)
            (
              rating: (n['rating'] as num?)?.toInt() ?? 0,
              media: AniListMedia.fromJson(n['mediaRecommendation'] as Json),
            ),
      ];
    }
    return result;
  }

  /// The related titles of For You's cross seeds (titles you loved on your
  /// other list), by seed id; For You keeps their source or adaptations.
  Future<Map<int, List<({String relationType, AniListMedia media})>>> fetchRelations(List<int> seedIds) async {
    final result = <int, List<({String relationType, AniListMedia media})>>{};
    if (seedIds.isEmpty) return result;
    final data = await cachedQuery(forYouRelationsQuery(seedIds));
    for (final seed in data.values.whereType<Json>()) {
      final edges = ((seed['relations'] as Json?)?['edges'] as List?) ?? const [];
      result[(seed['id'] as num).toInt()] = [
        for (final e in edges.whereType<Json>())
          if (e['node'] is Json && e['relationType'] is String)
            (relationType: e['relationType'] as String, media: AniListMedia.fromJson(e['node'] as Json)),
      ];
    }
    return result;
  }
}

/// AniList's answer for a user who keeps their list private.
bool isPrivateUser(Object? error) =>
    error is AniListError && RegExp('private user', caseSensitive: false).hasMatch(error.message);
