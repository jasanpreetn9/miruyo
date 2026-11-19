import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/episode_alerts.dart';
import 'core/providers.dart';
import 'features/shell/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // the fonts ship in fonts/; the app talks to AniList and nothing else
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [
      ('Fraunces', 'fraunces'),
      ('Schibsted Grotesk', 'schibstedgrotesk'),
      ('JetBrains Mono', 'jetbrainsmono'),
    ]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('fonts/OFL-$file.txt'));
    }
  });
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        // a tapped episode alert opens the title
        alertSchedulerProvider.overrideWith(
          (ref) => LocalAlertScheduler(onTap: (route) => unawaited(ref.read(routerProvider).push(route))),
        ),
      ],
      child: const MiruyoApp(),
    ),
  );
}
