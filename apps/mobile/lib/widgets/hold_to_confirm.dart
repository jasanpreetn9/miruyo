import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gestures/haptics.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// A destructive button that fills while held and only acts when full
/// (800ms). Letting go early drains it and nothing happens. Screen readers
/// get a confirm dialog instead of the hold.
class HoldToConfirm extends ConsumerStatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.icon,
    required this.onConfirmed,
    this.confirmTitle = 'Are you sure?',
    this.color = Accent.danger,
  });

  final String label;
  final IconData icon;
  final VoidCallback onConfirmed;

  /// The confirm dialog's question, for screen readers.
  final String confirmTitle;
  final Color color;

  @override
  ConsumerState<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends ConsumerState<HoldToConfirm> with SingleTickerProviderStateMixin {
  late final _fill = AnimationController(vsync: this, duration: GestureSpec.holdToDestroy)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        unawaited(ref.read(hapticsProvider).play(Haptic.warning));
        widget.onConfirmed();
      }
    });

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  void _down() {
    unawaited(ref.read(hapticsProvider).play(Haptic.light));
    unawaited(_fill.forward());
  }

  void _up() {
    if (_fill.isCompleted) return;
    // drains back faster than it filled
    unawaited(_fill.animateBack(0, duration: Motion.lift));
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.confirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: widget.color),
            child: Text(widget.label),
          ),
        ],
      ),
    );
    if (ok == true) widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.accessibleNavigationOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      hint: 'Hold to confirm',
      excludeSemantics: true,
      onTap: _confirm,
      child: GestureDetector(
        onTapDown: accessible ? null : (_) => _down(),
        onTapUp: accessible ? null : (_) => _up(),
        onTapCancel: accessible ? null : _up,
        onTap: accessible ? _confirm : null,
        child: Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: widget.color.withValues(alpha: 0.35)),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _fill,
                builder: (context, _) => FractionallySizedBox(
                  widthFactor: _fill.value,
                  child: ColoredBox(color: widget.color.withValues(alpha: 0.3), child: const SizedBox.expand()),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 20, color: widget.color),
                    const SizedBox(width: Space.x2),
                    Flexible(
                      child: AnimatedBuilder(
                        animation: _fill,
                        builder: (context, _) => Text(
                          _fill.value > 0 ? 'Keep holding…' : '${widget.label} · hold',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: widget.color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
