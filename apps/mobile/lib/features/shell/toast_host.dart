import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';

/// Toasts, bottom-centre above the tab bar, newest on top. Holding one
/// pauses its timer; swiping it sideways dismisses it.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    final controller = ref.read(toastProvider.notifier);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final toast in toasts)
          Padding(
            key: ValueKey(toast.id),
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion ? Duration.zero : Motion.overlay,
              curve: Motion.enter,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
              ),
              child: Dismissible(
                key: ValueKey('dismiss-${toast.id}'),
                onDismissed: (_) => controller.dismiss(toast.id),
                child: Listener(
                  onPointerDown: (_) => controller.pause(toast.id),
                  onPointerUp: (_) => controller.resume(toast.id),
                  onPointerCancel: (_) => controller.resume(toast.id),
                  child: _Toast(toast: toast, onDismiss: () => controller.dismiss(toast.id)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.toast, required this.onDismiss});

  final ToastData toast;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = switch (toast.tone) {
      ToastTone.success => (Symbols.check_circle_rounded, const Color(0xFF4ED98A)),
      ToastTone.error => (Symbols.error_rounded, Accent.danger),
      ToastTone.offline => (Symbols.cloud_off_rounded, TextTone.mid),
      ToastTone.info => (null, TextTone.mid),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, maxWidth: 480),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: Surface.s4,
          borderRadius: BorderRadius.circular(Corner.md),
          border: Border.all(color: Surface.line),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 12))],
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: iconColor, fill: 1), const SizedBox(width: 10)],
            Expanded(
              child: Text(
                toast.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (toast.action case final action?)
              TextButton(
                onPressed: () {
                  action.run();
                  onDismiss();
                },
                style: TextButton.styleFrom(
                  foregroundColor: context.mode.accentText,
                  minimumSize: const Size(Space.minTarget, Space.minTarget),
                  textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
