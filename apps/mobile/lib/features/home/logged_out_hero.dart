import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import 'home_data.dart';

/// The signed-out Home's opening (01): a tilted wall of trending covers
/// behind the pitch and the two ways in.
class LoggedOutHero extends ConsumerWidget {
  const LoggedOutHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    final wall = ref.watch(publicTrendingProvider(mode)).value ?? const [];
    final colors = context.mode;

    // a Stack only clips when it sees overflow, and transformed children
    // don't count, so the tilted wall needs its own clip
    return ClipRect(
      child: SizedBox(
        height: 400,
        child: Stack(
          children: [
            // the poster wall, tilted −6° and scaled from the top right
            Positioned.fill(
              child: Opacity(
                opacity: 0.8,
                child: Transform(
                  alignment: Alignment.topRight,
                  transform: Matrix4.identity()
                    ..rotateZ(-6 * math.pi / 180)
                    ..scaleByDouble(1.15, 1.15, 1, 1),
                  child: GridView.count(
                    crossAxisCount: 4,
                    padding: const EdgeInsets.all(Space.x4),
                    mainAxisSpacing: Space.x2,
                    crossAxisSpacing: Space.x2,
                    childAspectRatio: 2 / 3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final t in wall.take(16)) CoverImage(title: t, showMissing: false)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Surface.base, Color(0x66090B11), Color(0xB3090B11)],
                    stops: [0.38, 0.75, 1],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Surface.base, Color(0x00090B11)],
                    stops: [0, 0.4],
                  ),
                ),
              ),
            ),
            Positioned(
              left: Space.x5,
              right: Space.x5,
              top: Space.x14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every episode. Every chapter. One list.',
                    style: AppType.displayL.copyWith(fontSize: 32, height: 1.05),
                  ),
                  const SizedBox(height: Space.x4),
                  Text(
                    'miruyo syncs with your AniList account — track progress in one tap, '
                    'see what airs tonight, and find out what to watch next.',
                    style: AppType.body.copyWith(color: const Color(0xFFC4C9D6), height: 1.6),
                  ),
                  const SizedBox(height: Space.x4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/login'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Log in with AniList'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/browse'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          backgroundColor: Surface.s3,
                          foregroundColor: TextTone.high,
                          side: const BorderSide(color: Surface.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
