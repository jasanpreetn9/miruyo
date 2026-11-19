import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';

class ToastAction {
  const ToastAction(this.label, this.run);

  final String label;
  final void Function() run;
}

enum ToastTone { info, success, error, offline }

class ToastData {
  const ToastData({
    required this.id,
    required this.message,
    this.action,
    this.tone = ToastTone.info,
    this.duration = GestureSpec.undoShort,
  });

  final int id;
  final String message;
  final ToastAction? action;
  final ToastTone tone;
  final Duration duration;
}

/// Toasts stack bottom-centre above the tab bar: at most 3, newest on top.
/// Undo stays 5s for removals and bulk moves, 4s for everything else.
class ToastController extends Notifier<List<ToastData>> {
  static const maxVisible = 3;

  final _timers = <int, Timer>{};
  var _nextId = 0;

  @override
  List<ToastData> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const [];
  }

  /// Shows a toast and returns its id. [long] keeps it up for the removal
  /// Undo window (5s); errors stay a little longer still.
  int show(String message, {ToastAction? action, ToastTone tone = ToastTone.info, bool long = false}) {
    final id = ++_nextId;
    final duration = tone == ToastTone.error
        ? const Duration(seconds: 6)
        : long
        ? GestureSpec.undoLong
        : GestureSpec.undoShort;
    final toast = ToastData(id: id, message: message, action: action, tone: tone, duration: duration);
    final next = [toast, ...state];
    for (final dropped in next.skip(maxVisible)) {
      _timers.remove(dropped.id)?.cancel();
    }
    state = next.take(maxVisible).toList();
    _timers[id] = Timer(duration, () => dismiss(id));
    return id;
  }

  void dismiss(int id) {
    _timers.remove(id)?.cancel();
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
  }

  /// Holds a toast while a finger is on it (the touch form of pause-on-hover).
  void pause(int id) => _timers.remove(id)?.cancel();

  void resume(int id) {
    final toast = state.where((t) => t.id == id).firstOrNull;
    if (toast == null || _timers.containsKey(id)) return;
    _timers[id] = Timer(toast.duration, () => dismiss(id));
  }
}

final toastProvider = NotifierProvider<ToastController, List<ToastData>>(ToastController.new);
