import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/app_router.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/auth/view/login_page.dart';
import 'package:grip_club_mobile/features/auth/view/register_page.dart';
import 'package:grip_club_mobile/features/auth/view/splash_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobbies_page.dart';

import '../helpers/dashboard_harness.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _user = User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'rider',
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

/// Long enough to clear the splash floor in [AuthBloc]. The splash spinner
/// animates forever, so these tests pump fixed durations instead of settling.
const _pastSplashFloor = Duration(seconds: 1);

void main() {
  late AuthRepository repository;
  late AuthBloc bloc;
  late GoRouter router;

  setUp(() {
    repository = _MockAuthRepository();
    when(repository.logout).thenAnswer((_) async {});
    // The dashboard tabs resolve their blocs from the container, so the guard
    // cannot be exercised without one.
    registerDashboardStubs(auth: repository);
  });

  tearDown(() async {
    router.dispose();
    await bloc.close();
    await getIt.reset();
  });

  /// Mounts the real router over a real bloc — the guard is the thing under
  /// test, so nothing about it is stubbed.
  Future<void> pumpApp(WidgetTester tester) async {
    bloc = AuthBloc(repository: repository);
    router = createRouter(bloc);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('holds on the splash screen while the session is unknown', (
    tester,
  ) async {
    when(() => repository.hasStoredSession).thenReturn(true);
    when(repository.currentUser).thenAnswer((_) async => _user);

    await pumpApp(tester);
    bloc.add(const AuthStarted());
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(_pastSplashFloor);
  });

  testWidgets('sends a signed-out user to login', (tester) async {
    when(() => repository.hasStoredSession).thenReturn(false);

    await pumpApp(tester);
    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('lets a signed-out user reach register from login', (
    tester,
  ) async {
    when(() => repository.hasStoredSession).thenReturn(false);

    await pumpApp(tester);
    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pump();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    // The guard must not bounce /register back to /login.
    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('sends a restored session straight to the lobbies tab', (
    tester,
  ) async {
    when(() => repository.hasStoredSession).thenReturn(true);
    when(repository.currentUser).thenAnswer((_) async => _user);

    await pumpApp(tester);
    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pump();

    expect(find.byType(LobbiesPage), findsOneWidget);
  });

  testWidgets('keeps a signed-in user off the auth screens', (tester) async {
    when(() => repository.hasStoredSession).thenReturn(true);
    when(repository.currentUser).thenAnswer((_) async => _user);

    await pumpApp(tester);
    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pump();

    router.go(Routes.login);
    await tester.pumpAndSettle();

    expect(find.byType(LobbiesPage), findsOneWidget);
  });
}
