import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/episode_alerts.dart';
import 'core/providers.dart';
import 'features/shell/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // the fonts ship in google_fonts/; the app talks to AniList and nothing else
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [('Bricolage Grotesque', 'bricolagegrotesque'), ('Geist, Geist Mono', 'geist')]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('google_fonts/OFL-$file.txt'));
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
