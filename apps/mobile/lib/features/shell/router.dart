import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anilist/types.dart';

import '../browse/browse_screen.dart';
import '../detail/detail_screen.dart';
import '../for_you/for_you_screen.dart';
import '../home/home_screen.dart';
import '../list/list_data.dart' show ListSort;
import '../list/list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/login_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../person/character_screen.dart';
import '../person/staff_screen.dart';
import '../profile/settings_screen.dart';
import '../seasonal/seasonal_screen.dart';
import '../studio/studio_screen.dart';
import '../user/user_screen.dart';
import 'app_shell.dart';
import 'signed_out_prompt.dart';
import 'swipe_back.dart';
import 'tab_scroll.dart';

/// Tab roots, in tab-bar order.
const tabPaths = ['/', '/browse', '/seasonal', '/list', '/profile'];

final routerProvider = Provider<GoRouter>((ref) {
  StatefulShellBranch branch(String path, Widget Function(GoRouterState state) screen) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        // each tab scrolls back to the top when it's tapped again
        pageBuilder: (context, state) => NoTransitionPage(
          child: TabScrollScope(index: tabPaths.indexOf(path), child: screen(state)),
        ),
      ),
    ],
  );

  return GoRouter(
    observers: [_DismissKeyboard()],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          branch('/', (_) => const HomeScreen()),
          branch('/browse', (state) => BrowseScreen(query: state.uri.queryParametersAll)),
          branch('/seasonal', (state) => SeasonalScreen(query: state.uri.queryParameters)),
          branch(
            '/list',
            (state) => AccountGate(
              signedIn: MyListScreen(
                tab: MediaListStatus.parse(state.uri.queryParameters['tab']),
                list: state.uri.queryParameters['list'],
                sort: ListSort.values.where((s) => s.name == state.uri.queryParameters['sort']).firstOrNull,
              ),
              signedOut: const MyListSignedOut(),
            ),
          ),
          branch('/profile', (_) => const AccountGate(signedIn: ProfileScreen(), signedOut: ProfileSignedOut())),
        ],
      ),
      GoRoute(
        path: '/title/:id',
        // pushed pages swipe back from anywhere, as iOS's own apps do
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: DetailScreen(
            key: ValueKey(state.pathParameters['id']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/studio/:id',
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: StudioScreen(
            key: ValueKey(state.pathParameters['id']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            sort: state.uri.queryParameters['sort'] == 'newest' ? PersonSort.newest : PersonSort.popularity,
          ),
        ),
      ),
      GoRoute(
        path: '/staff/:id',
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: StaffScreen(
            key: ValueKey(state.pathParameters['id']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            sort: state.uri.queryParameters['sort'] == 'newest' ? PersonSort.newest : PersonSort.popularity,
          ),
        ),
      ),
      GoRoute(
        path: '/character/:id',
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: CharacterScreen(
            key: ValueKey(state.pathParameters['id']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/user/:name',
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: UserScreen(key: ValueKey(state.pathParameters['name']), name: state.pathParameters['name'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: LoginScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => SwipeBackPage(key: state.pageKey, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => SwipeBackPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/for-you',
        pageBuilder: (context, state) => SwipeBackPage(key: state.pageKey, child: const ForYouScreen()),
      ),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    ],
  );
});

/// Opening a page puts the keyboard away: a field focused in a tab (Browse's
/// search) would otherwise keep it up over the new page.
class _DismissKeyboard extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) FocusManager.instance.primaryFocus?.unfocus();
  }
}
