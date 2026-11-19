import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time in unix seconds, ticking once a second while something
/// on screen watches it (countdown chips, retry countdowns).
final clockProvider = StreamProvider.autoDispose<int>((ref) async* {
  int now() => clock.now().millisecondsSinceEpoch ~/ 1000;
  yield now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => now());
});

/// "0:12", "1:05": the design's rate-limit countdown format.
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
