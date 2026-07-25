import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/view/login_page.dart';
import 'package:grip_club_mobile/features/auth/view/register_page.dart';
import 'package:grip_club_mobile/features/auth/view/splash_page.dart';
import 'package:grip_club_mobile/features/dashboard/view/dashboard_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/create_lobby_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobbies_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobby_detail_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/my_lobbies_page.dart';
import 'package:grip_club_mobile/features/notifications/view/notifications_page.dart';
import 'package:grip_club_mobile/features/profile/view/profile_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app router with an auth guard.
///
/// [redirect] re-runs whenever [AuthBloc] emits (via [refreshListenable]), which
/// is what makes logging in or out navigate on its own — no `context.go` call in
/// the auth flow.
GoRouter createRouter(AuthBloc authBloc) => GoRouter(
  initialLocation: Routes.splash,
  navigatorKey: _rootNavigatorKey,
  debugLogDiagnostics: AppConfig.isDev,
  refreshListenable: GoRouterRefreshStream(authBloc.stream),
  redirect: (context, state) {
    final location = state.matchedLocation;

    final isAuthRoute = location == Routes.login || location == Routes.register;

    return switch (authBloc.state.status) {
      // Still validating the stored token: hold on the splash screen.
      AuthStatus.unknown => location == Routes.splash ? null : Routes.splash,
      // Both auth screens are reachable while signed out; anything else is not.
      AuthStatus.unauthenticated => isAuthRoute ? null : Routes.login,
      // Everything else — the dashboard, its tabs, the pages above it — is
      // allowed, so signed-in routes need no per-route guard.
      AuthStatus.authenticated =>
        isAuthRoute || location == Routes.splash ? Routes.home : null,
    };
  },
  routes: <RouteBase>[
    GoRoute(
      path: Routes.splash,
      name: Routes.splashName,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: Routes.login,
      name: Routes.loginName,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: Routes.register,
      name: Routes.registerName,
      builder: (context, state) => const RegisterPage(),
    ),
    // The dashboard. One branch per tab, each with its own navigator, so a tab
    // keeps its stack and scroll position while the others are off screen.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          DashboardPage(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.lobbies,
              name: Routes.lobbiesName,
              builder: (context, state) => const LobbiesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.myLobbies,
              name: Routes.myLobbiesName,
              builder: (context, state) => const MyLobbiesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.notifications,
              name: Routes.notificationsName,
              builder: (context, state) => const NotificationsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.profile,
              name: Routes.profileName,
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    // Pushed onto the root navigator: both cover the tab bar.
    GoRoute(
      path: Routes.lobbyDetail,
      name: Routes.lobbyDetailName,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          LobbyDetailPage(lobbyId: state.pathParameters['lobbyId'] ?? ''),
    ),
    GoRoute(
      path: Routes.createLobby,
      name: Routes.createLobbyName,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const MaterialPage<void>(
        fullscreenDialog: true,
        child: CreateLobbyPage(),
      ),
    ),
  ],
);

/// Adapts a bloc [Stream] to the [Listenable] that `GoRouter.refreshListenable`
/// expects.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
