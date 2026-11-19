import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/session.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../shell/top_bar.dart';

/// Login (09). AniList OAuth is the only sign-in, so the page is one
/// decision plus a plain note on what miruyo can and can't see. The
/// approval page opens in a sheet; pulling it down cancels.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    final result = await ref.read(sessionProvider.notifier).signIn();
    if (!mounted) return;
    final session = ref.read(sessionProvider);
    setState(() {
      _busy = false;
      switch (result) {
        case SignInCancelled():
          _notice = 'Not signed in. Nothing was shared.';
          _noticeIsError = false;
        case SignInFailed(:final message):
          _notice = message;
          _noticeIsError = true;
        case SignedIn() when !session.signedIn:
          _notice = 'Could not verify your AniList account. Please try again.';
          _noticeIsError = true;
        case SignedIn():
          break;
      }
    });
    // the first sign-in on this device goes through setup
    if (result is SignedIn && session.signedIn && mounted) {
      context.go(ref.read(prefsProvider).getString(PrefKeys.onboarded) == null ? '/welcome' : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    final link = AppType.caption.copyWith(color: TextTone.mid, decoration: TextDecoration.underline);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Symbols.close_rounded, color: TextTone.mid),
                ),
              ),
              const Spacer(),
              const Center(child: Logo(size: 56)),
              const SizedBox(height: Space.x6),
              Text('miruyo', textAlign: TextAlign.center, style: AppType.displayL),
              const SizedBox(height: Space.x3),
              Text(
                'Your AniList list, made fast: one-tap progress, a weekly airing calendar, '
                'and picks that explain themselves.',
                textAlign: TextAlign.center,
                style: AppType.bodyL.copyWith(color: TextTone.mid),
              ),
              const Spacer(),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x4),
                  child: Text(
                    _notice!,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: _noticeIsError ? Accent.danger : TextTone.mid),
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: TextTone.high,
                  foregroundColor: Surface.base,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.sm)),
                  textStyle: AppType.title.copyWith(fontSize: 16),
                ),
                icon: _busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: mode.onAccent),
                      )
                    : const Icon(Symbols.login_rounded, size: 20),
                label: const Text('Log in with AniList'),
              ),
              const SizedBox(height: Space.x2),
              TextButton(
                onPressed: () => context.go('/'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: TextTone.high,
                  textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                child: const Text('Browse without an account'),
              ),
              const SizedBox(height: Space.x4),
              Text(
                "You'll approve access on anilist.co. We never see your password, and only read "
                'or change your list when you ask. Revoke any time in AniList settings.',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: TextTone.low),
              ),
              const SizedBox(height: Space.x3),
              Text.rich(
                TextSpan(
                  style: AppType.caption.copyWith(color: TextTone.low),
                  children: [
                    const TextSpan(text: 'By logging in, you agree to the '),
                    TextSpan(
                      text: 'Terms of Use',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(Uri.parse('https://miruyo.jnagra.com/terms')),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(Uri.parse('https://miruyo.jnagra.com/privacy')),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x6),
            ],
          ),
        ),
      ),
    );
  }
}
