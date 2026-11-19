import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/auth_service.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';

import '../helpers.dart';

const viewer = {
  'Viewer': {
    'id': 42,
    'name': 'haruka_k',
    'avatar': {'large': null, 'medium': null},
    'unreadNotificationCount': 3,
    'mediaListOptions': {'scoreFormat': 'POINT_100'},
    'options': {'titleLanguage': 'ROMAJI', 'displayAdultContent': false, 'airingNotifications': true},
  },
};

void main() {
  late http.Response Function(http.Request) respond;
  late MemoryTokenStore tokens;
  late ProviderContainer container;

  Future<void> boot({String? token}) async {
    tokens = MemoryTokenStore(token);
    final client = AniListClient(httpClient: MockClient((req) async => respond(req)));
    container = await testContainer(client: client, overrides: [tokenStoreProvider.overrideWithValue(tokens)]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    // let the session read the token and fetch the viewer
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  SessionState session() => container.read(sessionProvider);

  setUp(() => respond = (_) => http.Response(jsonEncode({'data': viewer}), 200));

  test('with no stored token, starts signed out', () async {
    await boot();
    expect(session().authState, AuthState.signedOut);
    expect(session().titles.name, 'english');
  });

  test('with a stored token, fetches the viewer and turns on list sync', () async {
    await boot(token: 'tok');
    expect(session().authState, AuthState.signedIn);
    expect(session().user?.name, 'haruka_k');
    expect(session().scoreFormat, ScoreFormat.point100);
    expect(container.read(listStoreProvider.notifier).sync, isTrue);
    expect(container.read(anilistClientProvider).token, 'tok');
  });

  test('a rejected token signs out with a notice and forgets the token', () async {
    respond = (_) => http.Response(
      jsonEncode({
        'errors': [
          {'message': 'Invalid token', 'status': 400},
        ],
      }),
      400,
    );
    await boot(token: 'expired');
    expect(session().authState, AuthState.signedOut);
    expect(session().signOutReason, SignOutReason.expired);
    expect(tokens.token, isNull);
  });

  test('a rate limit keeps the token and schedules a retry', () async {
    respond = (_) => http.Response('{}', 429, headers: {'retry-after': '12'});
    await boot(token: 'tok');
    expect(session().authState, AuthState.error);
    expect(session().rateLimited, isTrue);
    expect(session().retryAt, isNotNull);
    expect(tokens.token, 'tok');
  });

  test('logout clears the token and the list', () async {
    await boot(token: 'tok');
    await container.read(sessionProvider.notifier).logout();
    expect(session().authState, AuthState.signedOut);
    expect(tokens.token, isNull);
    expect(container.read(listStoreProvider.notifier).sync, isFalse);
  });

  test('the mode is remembered on the device', () async {
    await boot();
    container.read(modeProvider.notifier).set(Mode.manga);
    expect(container.read(prefsProvider).getString(PrefKeys.mode), 'manga');
  });

  group('AuthService.parseCallback', () {
    test('reads the token from the fragment', () {
      final r = AuthService.parseCallback(
        'miruyo://auth#access_token=abc&token_type=Bearer&expires_in=31536000&state=s1',
        state: 's1',
      );
      expect((r as SignedIn).token, 'abc');
    });

    test('refuses a token from a sign-in it didn’t start', () {
      expect(
        AuthService.parseCallback('miruyo://auth#access_token=abc&state=forged', state: 's1'),
        isA<SignInFailed>(),
      );
      expect(AuthService.parseCallback('miruyo://auth#access_token=abc', state: 's1'), isA<SignInFailed>());
    });

    test('sends a fresh 128-bit state each time', () {
      expect(AuthService.newState(), matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(AuthService.newState(), isNot(AuthService.newState()));
    });

    test('reports AniList errors', () {
      final r = AuthService.parseCallback('miruyo://auth#error=access_denied&error_description=Denied', state: 's1');
      expect((r as SignInFailed).message, 'Denied');
    });

    test('fails without a token', () {
      expect(AuthService.parseCallback('miruyo://auth', state: 's1'), isA<SignInFailed>());
    });
  });
}
