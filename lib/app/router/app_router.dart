import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/view/login_page.dart';
import 'package:grip_club_mobile/features/auth/view/splash_page.dart';
import 'package:grip_club_mobile/features/home/view/home_page.dart';

/// Builds the app router with an auth guard.
///
/// [redirect] re-runs whenever [AuthBloc] emits (via [refreshListenable]), which
/// is what makes logging in or out navigate on its own — no `context.go` call in
/// the auth flow.
GoRouter createRouter(AuthBloc authBloc) => GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: AppConfig.isDev,
  refreshListenable: GoRouterRefreshStream(authBloc.stream),
  redirect: (context, state) {
    final location = state.matchedLocation;

    return switch (authBloc.state.status) {
      // Still validating the stored token: hold on the splash screen.
      AuthStatus.unknown => location == Routes.splash ? null : Routes.splash,
      AuthStatus.unauthenticated => location == Routes.login
          ? null
          : Routes.login,
      AuthStatus.authenticated =>
        location == Routes.login || location == Routes.splash
            ? Routes.home
            : null,
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
      path: Routes.home,
      name: Routes.homeName,
      builder: (context, state) => const HomePage(),
    ),
  ],
);

/// Adapts a bloc [Stream] to the [Listenable] that `GoRouter.refreshListenable`
/// expects.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream
        .asBroadcastStream()
        .listen((dynamic _) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
