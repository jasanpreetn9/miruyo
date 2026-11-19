import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'mode_toggle.dart';

/// The 見 mark on the mode accent.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    return AnimatedContainer(
      duration: Motion.overlay,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: mode.accent, borderRadius: BorderRadius.circular(size * 0.29)),
      child: Text(
        '見',
        style: AppType.wordmark.copyWith(fontSize: size * 0.57, fontWeight: FontWeight.w800, color: mode.onAccent),
      ),
    );
  }
}

/// The phone top bar: logo, the mode toggle, then the bell and avatar (or
/// Log In when signed out). Blurred over whatever scrolls beneath.
class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({super.key});

  static const height = 56.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // the bar has a fixed height, so its text doesn't grow (as iOS's own bars)
      MediaQuery.withNoTextScaling(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final mode = context.mode;
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height + top,
          padding: EdgeInsets.only(top: top, left: Space.gutter, right: Space.gutter - 4),
          decoration: const BoxDecoration(
            color: Color(0xD1090B11), // base at 82%
            border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: Row(
            children: [
              const Logo(),
              const SizedBox(width: 10),
              Expanded(child: Text('miruyo', style: AppType.wordmark.copyWith(fontSize: 18))),
              const ModeToggle(),
              const SizedBox(width: 6),
              if (session.signedIn) ...[
                _Bell(unread: (user?.unreadNotificationCount ?? 0) > 0, accent: mode.accent),
                _Avatar(url: user?.avatarMedium),
              ] else if (session.authState == AuthState.signedOut)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: FilledButton(
                    onPressed: () => context.push('/login'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: AppType.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Log In'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.accent});

  final bool unread;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread ? 'Notifications, unread' : 'Notifications',
      child: InkResponse(
        radius: 22,
        onTap: () => context.push('/notifications'),
        child: SizedBox(
          width: Space.minTarget,
          height: Space.minTarget,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Symbols.notifications_rounded, size: 20, color: TextTone.mid),
              if (unread)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Surface.base, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profile',
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        child: Container(
          width: 30,
          height: 30,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Surface.line),
            gradient: const LinearGradient(colors: [Accent.sora, Accent.fuji]),
          ),
          child: url == null ? null : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
