import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// The mobile AniList API client (anilist.co/settings/developer), passed with
/// `--dart-define=ANILIST_CLIENT_ID=…`. A client has one redirect URL, so
/// the app has its own, separate from the web's: `miruyo://auth`.
const anilistClientId = String.fromEnvironment('ANILIST_CLIENT_ID');

const callbackScheme = 'miruyo';

sealed class SignInResult {
  const SignInResult();
}

class SignedIn extends SignInResult {
  const SignedIn(this.token);
  final String token;
}

/// Closed the sheet (pulled it down, or Cancel): nothing was shared.
class SignInCancelled extends SignInResult {
  const SignInCancelled();
}

class SignInFailed extends SignInResult {
  const SignInFailed(this.message);
  final String message;
}

/// AniList OAuth, implicit grant, as on the web. The approval page opens in
/// ASWebAuthenticationSession (iOS) / a Custom Tab (Android): a sheet that
/// pulling down cancels, and the token comes back in the redirect's fragment.
class AuthService {
  const AuthService();

  /// `state` ties the redirect to this sign-in, so a miruyo:// link carrying
  /// someone else's token (another app, a web page) can't sign the viewer in.
  Uri authorizeUrl(String state) => Uri.https('anilist.co', '/api/v2/oauth/authorize', {
    'client_id': anilistClientId,
    'response_type': 'token',
    'state': state,
  });

  /// A fresh, unguessable `state` for one sign-in: 128 random bits as hex.
  static String newState() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<SignInResult> signIn() async {
    if (anilistClientId.isEmpty) {
      return const SignInFailed('This build has no AniList client id (ANILIST_CLIENT_ID).');
    }
    final state = newState();
    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: authorizeUrl(state).toString(),
        callbackUrlScheme: callbackScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: false),
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return const SignInCancelled();
      return SignInFailed(e.message ?? 'Sign-in failed.');
    }
    return parseCallback(callback, state: state);
  }

  /// Reads the redirect: `miruyo://auth#access_token=…&token_type=Bearer&state=…`.
  /// A token whose `state` isn't the one this sign-in sent is refused.
  static SignInResult parseCallback(String callback, {required String state}) {
    final uri = Uri.parse(callback);
    final params = Uri.splitQueryString(uri.fragment.isNotEmpty ? uri.fragment : uri.query);
    final error = params['error'];
    if (error != null) return SignInFailed(params['error_description'] ?? error);
    final token = params['access_token'];
    if (token == null || token.isEmpty) return const SignInFailed('AniList sent no access token.');
    if (params['state'] != state) return const SignInFailed('This sign-in didn’t come from miruyo. Please try again.');
    return SignedIn(token);
  }
}
