import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'top_bar.dart';

/// What a tab that needs an account shows while signed out: what it does
/// once you log in, and the way in.
class SignedOutPrompt extends ConsumerWidget {
  const SignedOutPrompt({super.key, required this.icon, required this.title, required this.body, this.footer});

  final IconData icon;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = context.mode;
    final expired = ref.watch(sessionProvider.select((s) => s.signOutReason == SignOutReason.expired));
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.x6, Space.x14, Space.x6, 120),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: mode.tint, borderRadius: BorderRadius.circular(Corner.lg)),
            child: Icon(icon, size: 32, color: mode.accentText),
          ),
        ),
        const SizedBox(height: Space.x6),
        Text(title, textAlign: TextAlign.center, style: AppType.heading.copyWith(fontSize: 24)),
        const SizedBox(height: Space.x3),
        Text(
          expired ? 'Your AniList sign-in expired. Log in again to pick up where you left off.' : body,
          textAlign: TextAlign.center,
          style: AppType.bodyL.copyWith(fontSize: 15, color: TextTone.mid),
        ),
        const SizedBox(height: Space.x6),
        FilledButton(
          onPressed: () => context.push('/login'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: TextTone.high,
            foregroundColor: Surface.base,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: const Text('Log in with AniList'),
        ),
        if (footer != null) ...[const SizedBox(height: Space.x8), footer!],
      ],
    );
  }
}

class MyListSignedOut extends ConsumerWidget {
  const MyListSignedOut({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnime = ref.watch(modeProvider).isAnime;
    return SignedOutPrompt(
      icon: Symbols.bookmarks_rounded,
      title: 'Your list lives on AniList',
      body:
          'Log in to see everything you’re ${isAnime ? 'watching' : 'reading'}, +1 in a tap, '
          'and move titles between ${isAnime ? 'Watching' : 'Reading'}, Planning and Completed.',
    );
  }
}

class ProfileSignedOut extends StatelessWidget {
  const ProfileSignedOut({super.key});

  @override
  Widget build(BuildContext context) {
    final link = AppType.body.copyWith(color: TextTone.mid);
    Widget item(String label, String url) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: link),
      trailing: const Icon(Symbols.open_in_new_rounded, size: 18, color: TextTone.low),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
    return SignedOutPrompt(
      icon: Symbols.person_rounded,
      title: 'Your profile and stats',
      body: 'Log in to see your favourites, what you’ve watched and read, and how you score.',
      footer: Column(
        children: [
          const Center(child: Logo(size: 32)),
          const SizedBox(height: Space.x4),
          const Divider(),
          item('Terms of Use', 'https://miruyo.jnagra.com/terms'),
          item('Privacy Policy', 'https://miruyo.jnagra.com/privacy'),
          item('About AniList', 'https://anilist.co'),
        ],
      ),
    );
  }
}

/// Shows [signedIn] for an account, [signedOut] otherwise. While the
/// session is still checking, the signed-out view would flash, so nothing.
class AccountGate extends ConsumerWidget {
  const AccountGate({super.key, required this.signedIn, required this.signedOut});

  final Widget signedIn;
  final Widget signedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sessionProvider.select((s) => s.authState))) {
      AuthState.signedOut => signedOut,
      AuthState.loading => const SizedBox.shrink(),
      _ => signedIn,
    };
  }
}
