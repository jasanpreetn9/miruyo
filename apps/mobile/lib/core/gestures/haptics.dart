import 'package:flutter/services.dart';

/// The haptic scale (Gestures · Overview, 22b). Each fires once per
/// threshold crossing; dragging back under a threshold disarms silently.
enum Haptic {
  /// Ticks while something changes under your finger: a page, a step, an
  /// item painted, a target entered.
  selection,

  /// A swipe arms, or a small change commits: −1, a switch flips, a reorder
  /// drops, Undo.
  light,

  /// Something opens or lifts: a peek, quick actions, a carried stack.
  medium,

  /// A positive commit: +1, added to Planning, moved, synced, last episode.
  success,

  /// Something was removed, or a close was blocked.
  warning,
}

/// Plays haptics. Swappable so widget tests can record what fired.
class Haptics {
  const Haptics();

  Future<void> play(Haptic kind) => switch (kind) {
    Haptic.selection => HapticFeedback.selectionClick(),
    Haptic.light => HapticFeedback.lightImpact(),
    Haptic.medium => HapticFeedback.mediumImpact(),
    Haptic.success => HapticFeedback.successNotification(),
    Haptic.warning => HapticFeedback.warningNotification(),
  };
}

/// Records instead of playing, for tests.
class RecordingHaptics extends Haptics {
  RecordingHaptics();

  final played = <Haptic>[];

  @override
  Future<void> play(Haptic kind) async => played.add(kind);
}
