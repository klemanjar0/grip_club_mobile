import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobby_detail_page.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

import '../../helpers/dashboard_harness.dart';
import '../../helpers/lobby_fixtures.dart';

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';

void main() {
  late DashboardMocks mocks;

  setUp(() => mocks = registerDashboardStubs());

  tearDown(() async => getIt.reset());

  Future<void> pumpDetail(WidgetTester tester, {Lobby? initialLobby}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LobbyDetailPage(lobbyId: _lobbyId, initialLobby: initialLobby),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an outsider is offered the join button and no address', (
    tester,
  ) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer((_) async => lobby());

    await pumpDetail(tester);

    expect(find.text('Join lobby'), findsOneWidget);
    expect(
      find.text('Join to see the exact address and the group chat link.'),
      findsOneWidget,
    );
  });

  testWidgets('a private lobby asks to request instead of join', (
    tester,
  ) async {
    when(
      () => mocks.lobbies.byId(_lobbyId),
    ).thenAnswer((_) async => Lobby.fromJson(lobbyJson(visibility: 'private')));

    await pumpDetail(tester);

    expect(find.text('Request to join'), findsOneWidget);
  });

  testWidgets('joining re-reads the lobby and shows what it granted', (
    tester,
  ) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer((_) async => lobby());
    when(() => mocks.memberships.join(_lobbyId)).thenAnswer(
      (_) async => Membership(
        lobbyId: _lobbyId,
        userId: 'u1',
        status: MembershipStatus.approved,
        joinedAt: DateTime.utc(2026, 8, 24),
      ),
    );

    await pumpDetail(tester);

    // The second read is the post-join one: it carries the address the first
    // one withheld.
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async => Lobby.fromJson(
        lobbyJson(
          role: 'member',
          membershipStatus: 'approved',
          canJoin: false,
          address: '12 Khreshchatyk',
        ),
      ),
    );

    await tester.tap(find.text('Join lobby'));
    await tester.pumpAndSettle();

    expect(find.text('You are in.'), findsOneWidget);
    expect(find.text('12 Khreshchatyk'), findsOneWidget);
    expect(find.text('Leave lobby'), findsOneWidget);
    expect(find.text('Join lobby'), findsNothing);
  });

  testWidgets('the admin is offered the edit and delete actions', (
    tester,
  ) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async => Lobby.fromJson(
        lobbyJson(role: 'admin', membershipStatus: 'approved', canJoin: false),
      ),
    );

    await pumpDetail(tester);

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('a member is not', (tester) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async => Lobby.fromJson(
        lobbyJson(role: 'member', membershipStatus: 'approved', canJoin: false),
      ),
    );

    await pumpDetail(tester);

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('an admin gets no membership action', (tester) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async => Lobby.fromJson(
        lobbyJson(role: 'admin', membershipStatus: 'approved', canJoin: false),
      ),
    );

    await pumpDetail(tester);

    // Admins cannot leave their own lobby; their actions are in the app bar.
    expect(find.text('Leave lobby'), findsNothing);
    expect(find.text('Join lobby'), findsNothing);
  });

  group('deleting', () {
    final asAdmin = Lobby.fromJson(
      lobbyJson(role: 'admin', membershipStatus: 'approved', canJoin: false),
    );

    /// Pushes the page through a real router: deleting pops, and the
    /// confirmation has to land somewhere.
    Future<void> pumpRouted(WidgetTester tester) async {
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/lobby'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/lobby',
            builder: (context, state) =>
                const LobbyDetailPage(lobbyId: _lobbyId),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> tapDelete(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
    }

    testWidgets('confirming deletes the lobby and leaves the page', (
      tester,
    ) async {
      when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer((_) async => asAdmin);
      when(() => mocks.lobbies.deleteLobby(_lobbyId)).thenAnswer((_) async {});

      await pumpRouted(tester);
      await tapDelete(tester);

      // Other people are in this lobby (`approved_count` is 3), so the warning
      // says what they lose.
      expect(
        find.textContaining('Everyone who joined is notified'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mocks.lobbies.deleteLobby(_lobbyId)).called(1);
      expect(find.text('Lobby deleted.'), findsOneWidget);
      // Back on the route underneath — there is no lobby left to show.
      expect(find.text('open'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('backing out of the dialog deletes nothing', (tester) async {
      when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer((_) async => asAdmin);

      await pumpRouted(tester);
      await tapDelete(tester);

      await tester.tap(find.text('Keep lobby'));
      await tester.pumpAndSettle();

      verifyNever(() => mocks.lobbies.deleteLobby(any()));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('a rejected delete keeps the lobby and says why', (
      tester,
    ) async {
      when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer((_) async => asAdmin);
      when(() => mocks.lobbies.deleteLobby(_lobbyId)).thenThrow(
        const ApiException(
          'Only the organizer can do that.',
          statusCode: 403,
          code: 'admin_only',
        ),
      );

      await pumpRouted(tester);
      await tapDelete(tester);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Only the organizer can do that.'), findsOneWidget);
      // Still on the lobby, and the action is available again.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('when the lobby is closed to the caller', () {
    const notAMember = ApiException(
      'Join the lobby to see its details.',
      statusCode: 403,
      code: 'not_a_member',
    );

    testWidgets('the feed\'s copy still renders, with its join button', (
      tester,
    ) async {
      // `GET /lobbies/{id}` shuts outsiders out, but the browse feed already
      // handed the page everything it needs.
      when(() => mocks.lobbies.byId(_lobbyId)).thenThrow(notAMember);

      await pumpDetail(
        tester,
        initialLobby: Lobby.fromJson(lobbyJson(visibility: 'private')),
      );

      expect(find.text('Request to join'), findsOneWidget);
      expect(find.text('Thursday night climb'), findsWidgets);
      // Nothing failed as far as the reader is concerned.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a deep link offers the join instead of a retry', (
      tester,
    ) async {
      when(() => mocks.lobbies.byId(_lobbyId)).thenThrow(notAMember);

      await pumpDetail(tester);

      expect(find.text('Members only'), findsOneWidget);
      expect(find.text('Join lobby'), findsOneWidget);
      // Retrying a 403 would just 403 again.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a real failure still offers a retry', (tester) async {
      when(
        () => mocks.lobbies.byId(_lobbyId),
      ).thenThrow(const ApiException('No internet connection.'));

      await pumpDetail(tester);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Join lobby'), findsNothing);
    });

    testWidgets('requesting from a deep link leaves it pending, not broken', (
      tester,
    ) async {
      when(() => mocks.lobbies.byId(_lobbyId)).thenThrow(notAMember);
      when(() => mocks.memberships.join(_lobbyId)).thenAnswer(
        (_) async => Membership(
          lobbyId: _lobbyId,
          userId: 'u1',
          status: MembershipStatus.pending,
          joinedAt: DateTime.utc(2026, 8, 24),
        ),
      );

      await pumpDetail(tester);
      await tester.tap(find.text('Join lobby'));
      await tester.pumpAndSettle();

      // The lobby stays unreadable until the organizer approves, so the page
      // says so rather than bouncing the reader out.
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.text('Join lobby'), findsNothing);
    });
  });

  testWidgets('a banned viewer is told, not offered a doomed button', (
    tester,
  ) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async =>
          Lobby.fromJson(lobbyJson(membershipStatus: 'banned', canJoin: false)),
    );

    await pumpDetail(tester);

    expect(find.text('You cannot join this lobby.'), findsOneWidget);
    expect(find.text('Join lobby'), findsNothing);
  });
}
