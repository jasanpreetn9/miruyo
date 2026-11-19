// Small preferences kept on the device, with the same keys as the web app's
// storage-keys.ts. The AniList token is not here: it lives in the keychain
// (see TokenStore).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class PrefKeys {
  static const mode = 'miruyo_mode';

  /// Set once the first-run setup has been finished or skipped.
  static const onboarded = 'miruyo_onboarded';

  /// `userId:mode` pairs whose empty-list quick-pick was skipped.
  static const quickPickSkipped = 'miruyo_quick_pick_skipped';

  /// My List's list/grid choice, shared by every tab.
  static const listView = 'miruyo_list_view';

  /// Media ids hidden from For You with "Not this".
  static const forYouDismissed = 'miruyo_for_you_dismissed';

  /// Seed ids muted on For You.
  static const forYouMuted = 'miruyo_for_you_muted';

  /// For You's "Tune picks" settings (JSON).
  static const forYouTune = 'miruyo_for_you_tune';

  /// "Remind me" reminders, as JSON (see Reminders).
  static const reminders = 'miruyo_reminders';

  /// Episode alerts on this phone: 'on', 'off', or unset (not asked yet).
  static const episodeAlerts = 'miruyo_episode_alerts';

  /// The rows coach mark has been seen.
  static const rowsCoachSeen = 'miruyo_rows_coach_seen';

  /// Browse density: 2, 3 or 0 for the list.
  static const browseDensity = 'miruyo_browse_density';

  /// The season chart's view: 'cards' or 'posters'.
  static const seasonView = 'miruyo_season_view';
}

extension PrefSets on SharedPreferences {
  Set<String> readSet(String key) => (getStringList(key) ?? const []).toSet();

  Future<void> addToSet(String key, String value) => setStringList(key, {...readSet(key), value}.toList());

  Future<void> removeFromSet(String key, String value) => setStringList(key, (readSet(key)..remove(value)).toList());
}

/// The AniList access token, in the iOS keychain / Android keystore. AniList
/// tokens last a year and can't be refreshed; a rejected one signs you out.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'anilist_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Exception {
      // a keychain that can't be read (e.g. restored to a new device) is the
      // same as no token: sign in again
      return null;
    }
  }

  Future<void> write(String? token) =>
      token == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: token);
}

/// An in-memory [TokenStore] for tests.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String? token) async => this.token = token;
}
