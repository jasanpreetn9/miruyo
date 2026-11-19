import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tests never reach the network, so fonts fall back to the default and
/// google_fonts' "unable to load" notes are kept out of the output.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final print = debugPrint;
  var inFontNote = false;
  debugPrint = (String? message, {int? wrapWidth}) {
    final m = message ?? '';
    if (m.startsWith('Error: google_fonts')) inFontNote = true;
    if (!inFontNote) print(message, wrapWidth: wrapWidth);
    if (m.startsWith("If troubleshooting doesn't solve")) inFontNote = false;
  };
  await testMain();
}
