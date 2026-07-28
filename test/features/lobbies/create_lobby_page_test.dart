import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/lobbies/view/create_lobby_page.dart';

import '../../helpers/dashboard_harness.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

User _profile({String country = 'Ukraine', String city = 'Kyiv'}) => User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'rider',
  country: country,
  city: city,
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

/// Long enough to clear the splash floor in [AuthBloc].
const _pastSplashFloor = Duration(seconds: 1);

void main() {
  late AuthRepository auth;
  late AuthBloc bloc;
  late GoRouter router;

  setUp(() {
    // The form is taller than the default 800x600 test surface.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          ..physicalSize = const Size(1000, 2400)
          ..devicePixelRatio = 1;
    addTearDown(() {
      view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    auth = _MockAuthRepository();
    when(() => auth.hasStoredSession).thenReturn(true);

    registerDashboardStubs(auth: auth);
  });

  tearDown(() async {
    router.dispose();
    await bloc.close();
    await getIt.reset();
  });

  /// Signs in with [user], then opens the create form over a placeholder route
  /// — the page pops with `context.pop`, so it needs somewhere to pop to.
  ///
  /// The bloc is built here rather than in `setUp` on purpose: a bloc created
  /// outside the test body emits on the enclosing zone, and its states then
  /// never reach the widget between pumps.
  Future<void> pumpCreate(WidgetTester tester, {required User user}) async {
    when(auth.currentUser).thenAnswer((_) async => user);

    bloc = AuthBloc(repository: auth);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/create'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreateLobbyPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the home location saved on the profile', (
    tester,
  ) async {
    await pumpCreate(tester, user: _profile());

    expect(find.text('Ukraine'), findsOneWidget);
    expect(find.text('Kyiv'), findsOneWidget);
  });

  testWidgets('opens empty when the profile has no home location', (
    tester,
  ) async {
    await pumpCreate(
      tester,
      user: _profile(country: '', city: ''),
    );

    // The two fields are still required — nothing was saved to fill them with.
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Ukraine'), findsNothing);
    expect(find.text('Kyiv'), findsNothing);
  });

  testWidgets('the prefill is a starting point, not a lock', (tester) async {
    await pumpCreate(tester, user: _profile());

    await tester.enterText(find.text('Kyiv'), 'Lviv');
    await tester.pumpAndSettle();

    expect(find.text('Lviv'), findsOneWidget);
    expect(find.text('Kyiv'), findsNothing);
  });
}
