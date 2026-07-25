import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/app_router.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/view/create_lobby_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobbies_page.dart';
import 'package:grip_club_mobile/features/lobbies/view/my_lobbies_page.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';
import 'package:grip_club_mobile/features/notifications/view/notifications_page.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';
import 'package:grip_club_mobile/features/profile/view/profile_page.dart';

import '../../helpers/dashboard_harness.dart';
import '../../helpers/lobby_fixtures.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _user = User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'rider',
  city: 'Kyiv',
  timeFilter: 'week',
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

/// Long enough to clear the splash floor in [AuthBloc].
const _pastSplashFloor = Duration(seconds: 1);

void main() {
  late AuthRepository repository;
  late DashboardMocks mocks;
  late AuthBloc bloc;
  late GoRouter router;

  setUp(() {
    repository = _MockAuthRepository();
    when(repository.logout).thenAnswer((_) async {});
    when(() => repository.hasStoredSession).thenReturn(true);
    when(repository.currentUser).thenAnswer((_) async => _user);

    mocks = registerDashboardStubs(auth: repository);
  });

  tearDown(() async {
    router.dispose();
    await bloc.close();
    await getIt.reset();
  });

  /// Mounts the real router and signs in, landing on the dashboard.
  Future<void> pumpDashboard(WidgetTester tester) async {
    bloc = AuthBloc(repository: repository);
    router = createRouter(bloc);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    bloc.add(const AuthStarted());
    await tester.pump(_pastSplashFloor);
    await tester.pumpAndSettle();
  }

  testWidgets('shows five destinations around the create button', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in [
      'Lobbies',
      'My lobbies',
      'Create',
      'Alerts',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing $label tab');
    }
    expect(find.byType(LobbiesPage), findsOneWidget);
  });

  testWidgets('switches branches without losing the others', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(MyLobbiesPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('rider@example.com'), findsOneWidget);

    // The lobbies branch was only hidden, never rebuilt: its bloc is the same
    // instance and it never refetched.
    verify(
      () => mocks.lobbies.browse(city: null, within: null, page: 0),
    ).called(1);
  });

  testWidgets('the centre + opens the create form instead of a tab', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(CreateLobbyPage), findsOneWidget);
    // It is pushed over the shell, so the tab bar is gone while it is open.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('badges the notifications tab with the unread count', (
    tester,
  ) async {
    when(mocks.notifications.unreadCount).thenAnswer((_) async => 3);

    await pumpDashboard(tester);
    getIt<NotificationsBadgeBloc>().add(const NotificationsBadgeRefreshed());
    await tester.pumpAndSettle();

    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  group('joining from the browse list', () {
    final public = Lobby.fromJson(lobbyJson(name: 'Open climb'));
    final private = Lobby.fromJson(
      lobbyJson(
        id: 'a1b2c3d4-0000-4000-8000-000000000002',
        name: 'Closed climb',
        visibility: 'private',
      ),
    );

    void stubFeed(List<Lobby> lobbies) =>
        when(
          () => mocks.lobbies.browse(
            city: any(named: 'city'),
            within: any(named: 'within'),
            page: any(named: 'page'),
          ),
        ).thenAnswer(
          (_) async => PageEnvelope<Lobby>(
            items: lobbies,
            page: 0,
            pageSize: 10,
            hasNext: false,
          ),
        );

    testWidgets('the label says what the button will actually do', (
      tester,
    ) async {
      stubFeed([public, private]);

      await pumpDashboard(tester);

      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Request to join'), findsOneWidget);
    });

    testWidgets('joining flips that card without reloading the list', (
      tester,
    ) async {
      stubFeed([public, private]);
      when(() => mocks.memberships.join(public.id)).thenAnswer(
        (_) async => Membership(
          lobbyId: public.id,
          userId: 'u1',
          status: MembershipStatus.approved,
          joinedAt: DateTime.utc(2026, 8, 24),
        ),
      );

      await pumpDashboard(tester);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      expect(find.text('You are in.'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
      expect(find.text('Member'), findsOneWidget);
      // The other card is untouched.
      expect(find.text('Request to join'), findsOneWidget);
    });

    testWidgets('a private lobby only sends a request', (tester) async {
      stubFeed([private]);
      when(() => mocks.memberships.join(private.id)).thenAnswer(
        (_) async => Membership(
          lobbyId: private.id,
          userId: 'u1',
          status: MembershipStatus.pending,
          joinedAt: DateTime.utc(2026, 8, 24),
        ),
      );

      await pumpDashboard(tester);
      await tester.tap(find.text('Request to join'));
      await tester.pumpAndSettle();

      expect(
        find.text('Request sent — the organizer will review it.'),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('My Lobbies offers no join button', (tester) async {
      when(() => mocks.lobbies.myLobbies(page: any(named: 'page'))).thenAnswer(
        (_) async => PageEnvelope<Lobby>(
          items: [Lobby.fromJson(lobbyJson(role: 'member', canJoin: false))],
          page: 0,
          pageSize: 10,
          hasNext: false,
        ),
      );

      await pumpDashboard(tester);
      await tester.tap(find.byIcon(Icons.groups_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Join'), findsNothing);
      expect(find.text('Member'), findsOneWidget);
    });
  });

  testWidgets('empty feeds explain themselves', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('No lobbies here yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Nothing on your calendar'), findsOneWidget);
  });
}
