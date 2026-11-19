import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/router.dart';

class MiruyoApp extends ConsumerWidget {
  const MiruyoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    // start checking the stored token as soon as the app opens
    ref.watch(sessionProvider);
    return MaterialApp.router(
      title: 'miruyo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(mode),
      // switching mode cross-fades the accent
      themeAnimationDuration: const Duration(milliseconds: 160),
      routerConfig: ref.watch(routerProvider),
      // Larger text is honoured up to 1.3×: past that, posters and rows
      // can't fit their titles at all. The bars stay fixed (FixedText).
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
    );
  }
}
