import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/list/list_store.dart';
import '../../core/notifications/episode_alerts.dart';
import '../../core/theme/tokens.dart';
import '../list/list_edit.dart';
import 'tab_bar.dart';
import 'tab_scroll.dart';
import 'toast_host.dart';
import 'top_bar.dart';

/// Fades a tab in when you switch to it, instead of cutting. Each tab keeps
/// its state (they stay in an IndexedStack); only the new one fades.
class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: Motion.overlay, value: 1);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !MediaQuery.disableAnimationsOf(context)) _fade.forward(from: 0.35);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _fade, curve: Motion.enter),
    child: widget.child,
  );
}

/// The tabbed frame: top bar, the current tab, toasts above the tab bar
/// (or My List's edit bar, while Edit is on).
/// Each tab keeps its own navigation stack and scroll position.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  /// Refreshes the bell while the app is open.
  Timer? _bell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(alertSchedulerProvider).start());
    _startBell();
    // the session may still be loading; _onSession picks up the sign-in
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _bell?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startBell() {
    _bell?.cancel();
    _bell = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(ref.read(sessionProvider.notifier).refreshUnreadCount());
    });
  }

  /// The bell's count, and the episode alerts from the current list.
  void _refresh() {
    unawaited(ref.read(sessionProvider.notifier).refreshUnreadCount());
    unawaited(ref.read(episodeAlertsProvider.notifier).sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // back in the app: send any list edits made while offline, and catch up
      unawaited(ref.read(listStoreProvider.notifier).flush());
      _refresh();
      _startBell();
    } else if (state == AppLifecycleState.paused) {
      _bell?.cancel();
    }
  }

  void _select(int index) {
    // tapping the current tab again returns it to its root, and to the top
    final again = index == widget.shell.currentIndex;
    if (again) ref.read(tabReselectProvider.notifier).reselect(index);
    widget.shell.goBranch(index, initialLocation: again);
  }

  @override
  Widget build(BuildContext context) {
    // signing in schedules the alerts; signing out clears them
    ref.listen(sessionProvider.select((s) => s.authState), (was, now) {
      if (was != now && (now == AuthState.signedIn || now == AuthState.signedOut)) {
        unawaited(ref.read(episodeAlertsProvider.notifier).sync());
      }
    });
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const TopBar(),
      body: Padding(
        padding: EdgeInsets.only(top: TopBar.height + MediaQuery.paddingOf(context).top),
        child: _TabFade(index: widget.shell.currentIndex, child: widget.shell),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ToastHost(),
          // My List's Edit mode takes the tab bar's place until Done
          if (ref.watch(listEditProvider.select((e) => e.editing)))
            const ListEditBar()
          else
            AppTabBar(index: widget.shell.currentIndex, onSelect: _select),
        ],
      ),
    );
  }
}
