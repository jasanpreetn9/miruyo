import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests render with the app's own fonts (pubspec `fonts:`), so text measures
/// as it does on a phone; without this every glyph is the test font's square.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (family, files) in [
    ('Fraunces', ['fonts/Fraunces.ttf', 'fonts/Fraunces-Italic.ttf']),
    ('Schibsted Grotesk', ['fonts/SchibstedGrotesk.ttf']),
    ('JetBrains Mono', ['fonts/JetBrainsMono.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }
  await testMain();
}
