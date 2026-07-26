import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';
import 'package:grip_club_mobile/features/members/view/lobby_members_page.dart';

import '../../helpers/dashboard_harness.dart';
import '../../helpers/member_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';
const _adminId = 'u0000000-0000-4000-8000-000000000001';
const _memberId = 'u0000000-0000-4000-8000-000000000002';

final _admin = User(
  id: _adminId,
  email: 'organizer@example.com',
  displayName: 'organizer',
  createdAt: DateTime.utc(2026),
);

void main() {
  late DashboardMocks mocks;
  late AuthBloc auth;

  setUpAll(() => registerFallbackValue(MembershipStatus.approved));

  setUp(() {
    mocks = registerDashboardStubs();
    auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(AuthState.authenticated(_admin));
  });

  tearDown(() async => getIt.reset());

  void stubRoster(MembershipStatus status, List<LobbyMember> members) => when(
    () => mocks.memberships.members(_lobbyId, status: status),
  ).thenAnswer((_) async => members);

  void stubEveryRoster({List<LobbyMember>? approved}) {
    stubRoster(
      MembershipStatus.approved,
      approved ??
          <LobbyMember>[
            member(id: _adminId, displayName: 'organizer'),
            member(id: _memberId, displayName: 'climber'),
          ],
    );
    stubRoster(MembershipStatus.pending, <LobbyMember>[
      member(id: _memberId, displayName: 'climber', status: 'pending'),
    ]);
    stubRoster(MembershipStatus.banned, const <LobbyMember>[]);
  }

  Future<void> pumpRoster(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(
          home: LobbyMembersPage(lobbyId: _lobbyId, lobbyName: 'Night climb'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the row menu for [name] and picks [action].
  Future<void> chooseAction(
    WidgetTester tester,
    String name,
    String action,
  ) async {
    await tester.tap(find.byTooltip('Manage $name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('lists the approved roster first', (tester) async {
    stubEveryRoster();

    await pumpRoster(tester);

    expect(find.text('organizer'), findsOneWidget);
    expect(find.text('climber'), findsOneWidget);
    expect(find.text('climber@example.com'), findsWidgets);
  });

  testWidgets('offers the admin nothing against their own row', (tester) async {
    // Every action against your own id is `403 cannot_target_self`, so the
    // menu is withheld rather than offered and refused.
    stubEveryRoster();

    await pumpRoster(tester);

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Organizer'), findsOneWidget);
    expect(find.byTooltip('Manage organizer'), findsNothing);
    expect(find.byTooltip('Manage climber'), findsOneWidget);
  });

  testWidgets('switches roster and reads the one it has not seen', (
    tester,
  ) async {
    stubEveryRoster();

    await pumpRoster(tester);
    await tester.tap(find.textContaining('Requests'));
    await tester.pumpAndSettle();

    verify(
      () =>
          mocks.memberships.members(_lobbyId, status: MembershipStatus.pending),
    ).called(1);
    expect(find.text('Approve'), findsNothing, reason: 'menu is not open');
    expect(find.byTooltip('Manage climber'), findsOneWidget);
  });

  testWidgets('says so when a roster is empty', (tester) async {
    stubEveryRoster();

    await pumpRoster(tester);
    await tester.tap(find.textContaining('Banned'));
    await tester.pumpAndSettle();

    expect(find.text('Nobody is banned'), findsOneWidget);
  });

  group('removing', () {
    testWidgets('asks first, then takes the row off the roster', (
      tester,
    ) async {
      stubEveryRoster();
      when(
        () => mocks.memberships.remove(_lobbyId, _memberId),
      ).thenAnswer((_) async {});

      await pumpRoster(tester);
      await chooseAction(tester, 'climber', 'Remove from lobby');

      // Destructive and notifies the person, so it is confirmed first.
      expect(find.text('Remove climber?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => mocks.memberships.remove(_lobbyId, _memberId)).called(1);
      expect(find.text('climber'), findsNothing);
      expect(find.text('climber is no longer on this list.'), findsOneWidget);
    });

    testWidgets('does nothing when the admin backs out', (tester) async {
      stubEveryRoster();

      await pumpRoster(tester);
      await chooseAction(tester, 'climber', 'Remove from lobby');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mocks.memberships.remove(any(), any()));
      expect(find.text('climber'), findsOneWidget);
    });
  });

  testWidgets('spells out that a ban cannot be undone', (tester) async {
    stubEveryRoster();
    when(() => mocks.memberships.ban(_lobbyId, _memberId)).thenAnswer(
      (_) async => Membership(
        lobbyId: _lobbyId,
        userId: _memberId,
        status: MembershipStatus.banned,
      ),
    );

    await pumpRoster(tester);
    await chooseAction(tester, 'climber', 'Ban from lobby');

    expect(find.textContaining('cannot be undone from their side'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Ban'));
    await tester.pumpAndSettle();

    verify(() => mocks.memberships.ban(_lobbyId, _memberId)).called(1);
    expect(find.text('climber is banned.'), findsOneWidget);
  });

  testWidgets('calls a ban lift what it is', (tester) async {
    // The same DELETE that removes a member lifts a ban, so the wording has to
    // come from the row rather than from the verb.
    stubEveryRoster();
    stubRoster(MembershipStatus.banned, <LobbyMember>[
      member(id: _memberId, displayName: 'climber', status: 'banned'),
    ]);

    await pumpRoster(tester);
    await tester.tap(find.textContaining('Banned'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage climber'));
    await tester.pumpAndSettle();

    expect(find.text('Lift ban'), findsOneWidget);
    expect(find.text('Remove from lobby'), findsNothing);
  });

  testWidgets('approving a request needs no confirmation', (tester) async {
    // An approval is ordinary and a decline can be asked again, so neither
    // interrupts the admin working through a queue of requests.
    stubEveryRoster();
    when(() => mocks.memberships.approve(_lobbyId, _memberId)).thenAnswer(
      (_) async => Membership(
        lobbyId: _lobbyId,
        userId: _memberId,
        status: MembershipStatus.approved,
      ),
    );

    await pumpRoster(tester);
    await tester.tap(find.textContaining('Requests'));
    await tester.pumpAndSettle();
    await chooseAction(tester, 'climber', 'Approve');

    verify(() => mocks.memberships.approve(_lobbyId, _memberId)).called(1);
    expect(find.text('climber is in.'), findsOneWidget);
  });

  testWidgets('offers a retry when the roster cannot be read at all', (
    tester,
  ) async {
    when(
      () => mocks.memberships.members(_lobbyId, status: any(named: 'status')),
    ).thenThrow(const ApiException('Admins only.', code: 'admin_only'));

    await pumpRoster(tester);

    expect(find.text('Admins only.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('keeps the roster on screen when an action fails', (
    tester,
  ) async {
    stubEveryRoster();
    when(
      () => mocks.memberships.remove(_lobbyId, _memberId),
    ).thenThrow(const ApiException('No internet connection.'));

    await pumpRoster(tester);
    await chooseAction(tester, 'climber', 'Remove from lobby');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('climber'), findsOneWidget);
  });
}
