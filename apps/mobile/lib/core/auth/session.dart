// Ported from apps/web/src/lib/state/session.svelte.ts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../anilist/client.dart';
import '../anilist/errors.dart';
import '../anilist/types.dart';
import '../catalog/mode.dart';
import '../catalog/score.dart';
import '../catalog/title.dart';
import '../list/list_store.dart';
import '../providers.dart';
import '../storage/prefs.dart';
import 'auth_service.dart';

/// in = signed in; loading = checking the token; error = couldn't reach
/// AniList to check it (the token is kept, so a retry can recover); out = no
/// account linked.
enum AuthState { loading, signedIn, error, signedOut }

/// Why the viewer was signed out without asking, shown once as a notice.
enum SignOutReason { expired }

/// How long to wait before re-checking the account after a non-429 failure.
const _networkRetry = Duration(seconds: 15);

class SessionState {
  const SessionState({
    this.authState = AuthState.loading,
    this.user,
    this.signOutReason,
    this.loadError = '',
    this.rateLimited = false,
    this.retryAt,
  });

  final AuthState authState;
  final AniListUser? user;
  final SignOutReason? signOutReason;

  /// Why the last viewer fetch failed, when [authState] is error.
  final String loadError;

  /// Whether that failure was AniList's rate limit.
  final bool rateLimited;

  /// When a failed viewer fetch retries on its own.
  final DateTime? retryAt;

  bool get signedIn => authState == AuthState.signedIn;

  /// The viewer's AniList setting; off when signed out.
  bool get showAdultContent => user?.displayAdultContent ?? false;

  ScoreFormat get scoreFormat => user?.scoreFormat ?? defaultScoreFormat;

  /// Signed in, titles follow the account's own language; signed out, English.
  TitlePreference get titles => signedIn ? TitlePreference.userPreferred : TitlePreference.english;

  SessionState copyWith({
    AuthState? authState,
    AniListUser? user,
    bool clearUser = false,
    SignOutReason? signOutReason,
    bool clearReason = false,
    String? loadError,
    bool? rateLimited,
    DateTime? retryAt,
    bool clearRetry = false,
  }) => SessionState(
    authState: authState ?? this.authState,
    user: clearUser ? null : (user ?? this.user),
    signOutReason: clearReason ? null : (signOutReason ?? this.signOutReason),
    loadError: loadError ?? this.loadError,
    rateLimited: rateLimited ?? this.rateLimited,
    retryAt: clearRetry ? null : (retryAt ?? this.retryAt),
  );
}

class Session extends Notifier<SessionState> {
  Timer? _retry;

  AniListClient get _client => ref.read(anilistClientProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  SessionState build() {
    ref.onDispose(() => _retry?.cancel());
    // AniList rejected the token (expired or revoked) on any request
    _client.onUnauthorized = expire;
    Future.microtask(_init);
    return const SessionState();
  }

  Future<void> _init() async {
    final token = await _tokens.read();
    if (token == null) {
      state = state.copyWith(authState: AuthState.signedOut);
      return;
    }
    _client.token = token;
    await loadCurrentUser();
  }

  /// Fetches the viewer. On failure other than a rejected token, keeps the
  /// token and retries on its own (after the rate-limit window, else shortly).
  Future<void> loadCurrentUser() async {
    _retry?.cancel();
    state = state.copyWith(authState: AuthState.loading, loadError: '', rateLimited: false, clearRetry: true);
    try {
      final user = await _client.fetchViewer();
      state = state.copyWith(authState: AuthState.signedIn, user: user, clearReason: true);
      ref.read(listStoreProvider.notifier).sync = true;
      unawaited(ref.read(listStoreProvider.notifier).flush());
    } on AniListError catch (err) {
      if (err.isUnauthorized) return expire();
      final wait = err.isRateLimit ? Duration(seconds: err.retryAfter ?? defaultRetryAfter) : _networkRetry;
      state = state.copyWith(
        authState: AuthState.error,
        loadError: err.message,
        rateLimited: err.isRateLimit,
        retryAt: DateTime.now().add(wait),
      );
      _retry = Timer(wait, loadCurrentUser);
    }
  }

  /// Signs in with AniList. Returns the result so the login screen can say
  /// what happened ("Not signed in. Nothing was shared.").
  Future<SignInResult> signIn([AuthService auth = const AuthService()]) async {
    final result = await auth.signIn();
    if (result is SignedIn) await setToken(result.token);
    return result;
  }

  Future<void> setToken(String token) async {
    await _tokens.write(token);
    _client
      ..token = token
      ..clearCache();
    await loadCurrentUser();
  }

  Future<void> logout() async {
    _retry?.cancel();
    await _tokens.write(null);
    _client
      ..token = null
      ..clearCache();
    final list = ref.read(listStoreProvider.notifier)
      ..sync = false
      ..clear();
    await ref.read(databaseProvider).clearViewerData();
    await list.refreshQueued();
    state = const SessionState(authState: AuthState.signedOut);
  }

  /// Signed out because AniList stopped accepting the token.
  Future<void> expire() async {
    await logout();
    state = state.copyWith(signOutReason: SignOutReason.expired);
  }

  void dismissSignOutReason() => state = state.copyWith(clearReason: true);

  /// Saves account settings on AniList and applies the result locally.
  /// Throws if AniList rejects it.
  Future<void> updateSettings(ViewerSettings settings) async {
    final saved = await _client.updateViewerSettings(settings);
    final user = state.user;
    if (user == null) return;
    final formatChanged = saved.scoreFormat != null && saved.scoreFormat != user.scoreFormat;
    state = state.copyWith(
      user: user.copyWith(
        scoreFormat: saved.scoreFormat,
        titleLanguage: saved.titleLanguage,
        displayAdultContent: saved.displayAdultContent,
        airingNotifications: saved.airingNotifications,
      ),
    );
    // entries held locally carry scores in the old format; screens re-seed
    // them in the new one on their next load
    if (formatChanged) ref.read(listStoreProvider.notifier).clear();
  }

  /// The bell's count, refreshed without refetching the whole viewer.
  Future<void> refreshUnreadCount() async {
    if (!state.signedIn) return;
    try {
      setUnreadCount(await _client.fetchUnreadCount());
    } on AniListError {
      // the bell keeps its last count; the next refresh tries again
    }
  }

  void setUnreadCount(int count) {
    final user = state.user;
    if (user != null && user.unreadNotificationCount != count) {
      state = state.copyWith(user: user.copyWith(unreadNotificationCount: count));
    }
  }
}

final sessionProvider = NotifierProvider<Session, SessionState>(Session.new);

/// Anime or Manga, remembered on the device.
class ModeController extends Notifier<Mode> {
  @override
  Mode build() => Mode.parse(ref.read(prefsProvider).getString(PrefKeys.mode));

  void set(Mode mode) {
    if (mode == state) return;
    state = mode;
    unawaited(ref.read(prefsProvider).setString(PrefKeys.mode, mode.name));
  }
}

final modeProvider = NotifierProvider<ModeController, Mode>(ModeController.new);
