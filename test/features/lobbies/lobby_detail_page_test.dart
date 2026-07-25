import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
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

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LobbyDetailPage(lobbyId: _lobbyId)),
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

  testWidgets('an admin gets no membership action', (tester) async {
    when(() => mocks.lobbies.byId(_lobbyId)).thenAnswer(
      (_) async => Lobby.fromJson(
        lobbyJson(role: 'admin', membershipStatus: 'approved', canJoin: false),
      ),
    );

    await pumpDetail(tester);

    // Admins cannot leave their own lobby; deleting it is the follow-up pass.
    expect(find.text('Leave lobby'), findsNothing);
    expect(find.text('Join lobby'), findsNothing);
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
