import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/notifications/episode_alerts.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';

import '../helpers.dart';

const now = 1800000000;

Json media(int id, {String type = 'ANIME', int? nextAt, int ep = 5}) => {
  'id': id,
  'type': type,
  'format': 'TV',
  'title': {'romaji': 'Show $id', 'userPreferred': 'Show $id'},
  'coverImage': <String, Object>{},
  'nextAiringEpisode': ?(nextAt == null ? null : {'episode': ep, 'airingAt': nextAt, 'timeUntilAiring': 0}),
};

Json entry(Json m, {String status = 'CURRENT'}) => {
  'id': (m['id'] as int) * 10,
  'mediaId': m['id'],
  'status': status,
  'progress': 1,
  'score': 0,
  'updatedAt': now,
  'media': m,
};

CollectionEntry collection(Json e) => CollectionEntry.fromJson(e);

/// Signed in without the keychain or AniList.
class _SignedIn extends Session {
  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(id: 1, name: 'rin'),
  );
}

class _SignedOut extends Session {
  @override
  SessionState build() => const SessionState(authState: AuthState.signedOut);
}

void main() {
  final at = DateTime.fromMillisecondsSinceEpoch(now * 1000, isUtc: true);

  group('planAlerts', () {
    test('the next episode of what you watch or rewatch, soonest first', () {
      final alerts = planAlerts([
        collection(entry(media(1, nextAt: now + 7200, ep: 9))),
        collection(entry(media(2, nextAt: now + 3600, ep: 3), status: 'REPEATING')),
        collection(entry(media(3, nextAt: now + 60), status: 'PLANNING')), // not watching
        collection(entry(media(4, nextAt: now + 60), status: 'PAUSED')),
        collection(entry(media(5, nextAt: now - 60))), // already out
        collection(entry(media(6))), // nothing scheduled
        collection(entry(media(7, type: 'MANGA', nextAt: now + 60))),
      ], now: at);
      expect(alerts.map((a) => a.mediaId), [2, 1]);
      expect((alerts.first.title, alerts.first.body, alerts.first.route), ('Show 2', 'Episode 3 is out', '/title/2'));
      expect(alerts.first.at, at.add(const Duration(hours: 1)));
    });

    test('keeps under iOS\'s limit of pending notifications', () {
      final many = [for (var i = 1; i <= 80; i++) collection(entry(media(i, nextAt: now + i * 60)))];
      final alerts = planAlerts(many, now: at);
      expect(alerts, hasLength(maxAlerts));
      expect(alerts.last.mediaId, maxAlerts);
    });
  });

  group('EpisodeAlerts', () {
    // AniList answers with one watched show airing in an hour
    final client = AniListClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'MediaListCollection': {
                'lists': [
                  {
                    'status': 'CURRENT',
                    'isCustomList': false,
                    'entries': [entry(media(1, nextAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, ep: 2))],
                  },
                ],
              },
            },
          }),
          200,
        ),
      ),
    );

    test('off until turned on; turning on asks once, then schedules', () async {
      final fake = FakeAlertScheduler();
      final container = await testContainer(
        client: client,
        alerts: fake,
        overrides: [sessionProvider.overrideWith(_SignedIn.new)],
      );
      addTearDown(container.dispose);
      final alerts = container.read(episodeAlertsProvider.notifier);
      expect((container.read(episodeAlertsProvider), alerts.undecided), (false, true));

      await alerts.sync();
      expect(fake.scheduled, isEmpty);

      expect(await alerts.enable(), isTrue);
      expect(fake.permissionAsks, 1);
      expect(fake.scheduled.single.body, 'Episode 2 is out');
      expect(container.read(prefsProvider).getString(PrefKeys.episodeAlerts), 'on');

      await alerts.disable();
      expect(fake.scheduled, isEmpty);
      expect(alerts.undecided, isFalse);
    });

    test('a refused permission leaves them off', () async {
      final fake = FakeAlertScheduler(allowed: false);
      final container = await testContainer(
        client: client,
        alerts: fake,
        overrides: [sessionProvider.overrideWith(_SignedIn.new)],
      );
      addTearDown(container.dispose);
      expect(await container.read(episodeAlertsProvider.notifier).enable(), isFalse);
      expect(container.read(episodeAlertsProvider), isFalse);
      expect(fake.scheduled, isEmpty);
    });
  });

  group('Reminders', () {
    test('merge with the list\'s alerts: one per title, the soonest, nothing past', () {
      EpisodeAlert a(int id, int inMinutes, {int ep = 1}) => EpisodeAlert(
        mediaId: id,
        title: 'Show $id',
        episode: ep,
        at: at.add(Duration(minutes: inMinutes)),
      );
      final merged = mergeAlerts([a(1, 60), a(2, 30)], [a(1, 120, ep: 2), a(3, 10), a(4, -5)], now: at);
      expect(merged.map((x) => (x.mediaId, x.episode)), [(3, 1), (2, 1), (1, 1)]);
    });

    test('work signed out, survive a restart, and come off', () async {
      final fake = FakeAlertScheduler();
      final container = await testContainer(alerts: fake, overrides: [sessionProvider.overrideWith(_SignedOut.new)]);
      addTearDown(container.dispose);
      final soon = DateTime.now().toUtc().add(const Duration(hours: 2));
      final reminders = container.read(remindersProvider.notifier);

      expect(await reminders.add(EpisodeAlert(mediaId: 9, title: 'Show 9', episode: 4, at: soon)), isTrue);
      expect(fake.permissionAsks, 1);
      expect(fake.scheduled.single.mediaId, 9);

      // read back from the device, as on the next launch
      container.invalidate(remindersProvider);
      expect(container.read(remindersProvider).single.episode, 4);

      await container.read(remindersProvider.notifier).remove(9);
      expect(fake.scheduled, isEmpty);
      expect(container.read(remindersProvider), isEmpty);
    });

    test('not set when notifications are refused', () async {
      final fake = FakeAlertScheduler(allowed: false);
      final container = await testContainer(alerts: fake, overrides: [sessionProvider.overrideWith(_SignedOut.new)]);
      addTearDown(container.dispose);
      final added = await container
          .read(remindersProvider.notifier)
          .add(
            EpisodeAlert(
              mediaId: 9,
              title: 'Show 9',
              episode: 4,
              at: DateTime.now().toUtc().add(const Duration(hours: 2)),
            ),
          );
      expect(added, isFalse);
      expect(container.read(remindersProvider), isEmpty);
    });
  });
}
