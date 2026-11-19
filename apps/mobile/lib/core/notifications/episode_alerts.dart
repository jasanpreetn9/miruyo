// Episode alerts: a notification on this phone when a new episode of
// something you're watching comes out. AniList publishes each show's next
// airing time, so the alerts are scheduled on the device ahead of time (no
// server, and they fire with the app closed). They're rescheduled whenever
// the app starts or comes back, which picks up each following episode.
//
// Reminders ("Remind me" on a title or an upcoming slot) are one-off alerts
// for a single episode of anything, on the list or not, signed in or not.
// They share the scheduler, so both stay under iOS's limit together.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../anilist/types.dart';
import '../auth/session.dart';
import '../catalog/title.dart';
import '../providers.dart';
import '../storage/prefs.dart';

/// iOS keeps at most 64 pending notifications per app.
const maxAlerts = 60;

class EpisodeAlert {
  const EpisodeAlert({required this.mediaId, required this.title, required this.episode, required this.at});

  final int mediaId;
  final String title;
  final int episode;
  final DateTime at;

  String get body => 'Episode $episode is out';

  /// What a tap opens.
  String get route => '/title/$mediaId';

  Map<String, Object> toJson() => {
    'mediaId': mediaId,
    'title': title,
    'episode': episode,
    'at': at.millisecondsSinceEpoch,
  };

  static EpisodeAlert fromJson(Map<String, Object?> json) => EpisodeAlert(
    mediaId: json['mediaId']! as int,
    title: json['title']! as String,
    episode: json['episode']! as int,
    at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int, isUtc: true),
  );
}

/// [alerts] and [reminders] together: one per title (the soonest, since a
/// notification's id is its title's), only those still to come, soonest
/// first, at most [maxAlerts].
List<EpisodeAlert> mergeAlerts(List<EpisodeAlert> alerts, List<EpisodeAlert> reminders, {required DateTime now}) {
  final byTitle = <int, EpisodeAlert>{};
  for (final a in [...alerts, ...reminders]) {
    if (!a.at.isAfter(now)) continue;
    final had = byTitle[a.mediaId];
    if (had == null || a.at.isBefore(had.at)) byTitle[a.mediaId] = a;
  }
  return (byTitle.values.toList()..sort((a, b) => a.at.compareTo(b.at))).take(maxAlerts).toList();
}

/// The alerts to schedule: the next episode of every anime you're watching
/// or rewatching that airs after [now], soonest first, at most [maxAlerts].
List<EpisodeAlert> planAlerts(
  List<CollectionEntry> entries, {
  required DateTime now,
  TitlePreference titles = TitlePreference.userPreferred,
}) {
  final alerts = <EpisodeAlert>[];
  for (final c in entries) {
    final status = c.entry.status;
    if (status != MediaListStatus.current && status != MediaListStatus.repeating) continue;
    if (c.media.type != MediaType.anime) continue;
    final next = c.media.nextAiringEpisode;
    if (next == null) continue;
    final at = DateTime.fromMillisecondsSinceEpoch(next.airingAt * 1000, isUtc: true);
    if (!at.isAfter(now)) continue;
    alerts.add(
      EpisodeAlert(mediaId: c.media.id, title: pickTitle(c.media.title, titles), episode: next.episode, at: at),
    );
  }
  alerts.sort((a, b) => a.at.compareTo(b.at));
  return alerts.take(maxAlerts).toList();
}

/// The phone's notification system, behind an interface so tests can fake it.
abstract class AlertScheduler {
  /// Starts listening for taps on alerts.
  Future<void> start();

  /// Asks to show notifications. Resolves to whether it's allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled alert with [alerts].
  Future<void> replaceAll(List<EpisodeAlert> alerts);

  Future<void> cancelAll();
}

class LocalAlertScheduler implements AlertScheduler {
  LocalAlertScheduler({required this.onTap});

  /// Called with the alert's route when one is tapped.
  final void Function(String route) onTap;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      // permission is asked for when alerts are turned on, not at launch
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onTap(r.payload!);
      },
    );
    // opened by tapping an alert while the app wasn't running
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) onTap(payload);
  }();

  /// Starts listening for taps (and handles a tap that opened the app).
  @override
  Future<void> start() => _init();

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> replaceAll(List<EpisodeAlert> alerts) async {
    await _init();
    await _plugin.cancelAll();
    for (final a in alerts) {
      await _plugin.zonedSchedule(
        id: a.mediaId,
        title: a.title,
        body: a.body,
        payload: a.route,
        scheduledDate: tz.TZDateTime.from(a.at, tz.UTC),
        // within a few minutes is fine, and needs no exact-alarm permission
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(threadIdentifier: 'episodes-${a.mediaId}'),
          android: const AndroidNotificationDetails(
            'episodes',
            'New episodes',
            channelDescription: 'When a new episode of something you are watching comes out',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        'episode alerts: ${pending.length} scheduled; next ${alerts.firstOrNull?.title} at ${alerts.firstOrNull?.at}',
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}

/// Replaced in main() with one that opens tapped alerts; tests fake it.
final alertSchedulerProvider = Provider<AlertScheduler>((ref) => LocalAlertScheduler(onTap: (_) {}));

/// Episode alerts are on for this device. Off until turned on, since turning
/// them on asks for permission.
class EpisodeAlerts extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getString(PrefKeys.episodeAlerts) == 'on';

  /// Whether the Notifications screen should still offer them.
  bool get undecided => ref.read(prefsProvider).getString(PrefKeys.episodeAlerts) == null;

  /// Turns them on if the phone allows it. Resolves to whether it did.
  Future<bool> enable() async {
    final allowed = await ref.read(alertSchedulerProvider).requestPermission();
    await ref.read(prefsProvider).setString(PrefKeys.episodeAlerts, allowed ? 'on' : 'off');
    state = allowed;
    if (allowed) await sync();
    return allowed;
  }

  Future<void> disable() async {
    await ref.read(prefsProvider).setString(PrefKeys.episodeAlerts, 'off');
    state = false;
    await sync();
  }

  /// The list's alerts as last planned, for rescheduling reminders offline.
  List<EpisodeAlert>? _planned;

  /// Reschedules from the current list and the reminders: on start, on
  /// resume, after sign-in, when a reminder changes. Signed out or turned
  /// off, only reminders stay scheduled. Quietly keeps what's there when
  /// AniList can't be reached.
  Future<void> sync() async {
    final scheduler = ref.read(alertSchedulerProvider);
    final session = ref.read(sessionProvider);
    final userId = session.user?.id;
    final reminders = ref.read(remindersProvider);
    final now = clock.now().toUtc();
    if (!state || userId == null) {
      // still loading the session: leave things as they are
      if (state && session.authState == AuthState.loading) return;
      _planned = null;
      if (reminders.isEmpty) return scheduler.cancelAll();
      return scheduler.replaceAll(mergeAlerts(const [], reminders, now: now));
    }
    try {
      final fetched = await ref.read(anilistClientProvider).fetchListCollection(userId, MediaType.anime);
      _planned = planAlerts(fetched.data, now: now, titles: session.titles);
    } on Exception {
      // offline or rate limited: what's scheduled still fires; a changed
      // reminder is added to the list's alerts as last planned
      if (_planned == null) return;
    }
    await scheduler.replaceAll(mergeAlerts(_planned!, reminders, now: now));
  }
}

final episodeAlertsProvider = NotifierProvider<EpisodeAlerts, bool>(EpisodeAlerts.new);

/// "Remind me": one-off alerts for single episodes, kept on the device.
class Reminders extends Notifier<List<EpisodeAlert>> {
  @override
  List<EpisodeAlert> build() {
    final now = clock.now().toUtc();
    return [
      for (final raw in ref.read(prefsProvider).getStringList(PrefKeys.reminders) ?? const <String>[])
        if (_decode(raw) case final r? when r.at.isAfter(now)) r,
    ];
  }

  static EpisodeAlert? _decode(String raw) {
    try {
      return EpisodeAlert.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null; // an older format
    }
  }

  /// The reminder set for [mediaId], if any.
  EpisodeAlert? of(int mediaId) => state.where((r) => r.mediaId == mediaId).firstOrNull;

  /// Sets a reminder if the phone allows notifications. Resolves to whether
  /// it did.
  Future<bool> add(EpisodeAlert reminder) async {
    if (!await ref.read(alertSchedulerProvider).requestPermission()) return false;
    await _save([...state.where((r) => r.mediaId != reminder.mediaId), reminder]);
    return true;
  }

  Future<void> remove(int mediaId) => _save(state.where((r) => r.mediaId != mediaId).toList());

  Future<void> _save(List<EpisodeAlert> reminders) async {
    state = reminders;
    await ref.read(prefsProvider).setStringList(PrefKeys.reminders, [for (final r in reminders) jsonEncode(r)]);
    await ref.read(episodeAlertsProvider.notifier).sync();
  }
}

final remindersProvider = NotifierProvider<Reminders, List<EpisodeAlert>>(Reminders.new);
