import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../../features/connection/screens/discovery_screen.dart';
import '../../features/connection/screens/pair_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/terminal/screens/terminal_screen.dart';
import '../../features/files/screens/file_browser_screen.dart';
import '../../features/actions/screens/actions_screen.dart';
import '../../features/actions/screens/screen_viewer_screen.dart';
import '../../features/files/screens/file_viewer_screen.dart';
import '../../features/debug/screens/network_log_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifies GoRouter to re-evaluate redirects when connection state changes,
/// WITHOUT recreating the entire router instance.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(connectionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/discover',
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final conn = ref.read(connectionProvider);
      final location = state.matchedLocation;
      final isOnAuth = location == '/discover' || location.startsWith('/pair') || location == '/debug-log';

      // Has token → redirect away from auth screens to dashboard
      if (conn.token != null && isOnAuth) return '/dashboard';
      // No token → redirect away from protected screens to discover
      if (conn.token == null && !isOnAuth) return '/discover';
      // Otherwise don't redirect
      return null;
    },
    routes: [
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: '/pair',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PairScreen(
            host: extra['host'] as String?,
            port: extra['port'] as int?,
            baseUrl: extra['baseUrl'] as String?,
            serverName: extra['name'] as String? ?? 'Server',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/terminal',
              builder: (context, state) => const TerminalScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/files',
              builder: (context, state) => const FileBrowserScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/actions',
              builder: (context, state) => const ActionsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/screen-viewer',
        builder: (context, state) => const ScreenViewerScreen(),
      ),
      GoRoute(
        path: '/file-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FileViewerScreen(
            path: extra['path'] as String,
            fileName: extra['fileName'] as String,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/debug-log',
        builder: (context, state) => const NetworkLogScreen(),
      ),
    ],
  );
});
