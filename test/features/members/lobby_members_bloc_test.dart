import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/bloc/lobby_members_bloc.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

import '../../helpers/member_fixtures.dart';

class _MockMembershipRepository extends Mock implements MembershipRepository {}

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';
const _userId = 'u0000000-0000-4000-8000-000000000002';

final _approved = <LobbyMember>[
  member(id: 'u1', displayName: 'organizer'),
  member(id: _userId, displayName: 'climber'),
];

final _pending = <LobbyMember>[
  member(id: _userId, displayName: 'climber', status: 'pending'),
];

void main() {
  late MembershipRepository memberships;

  // `any()` needs a sample value for every non-primitive argument type.
  setUpAll(() => registerFallbackValue(MembershipStatus.approved));

  setUp(() => memberships = _MockMembershipRepository());

  LobbyMembersBloc build() =>
      LobbyMembersBloc(lobbyId: _lobbyId, memberships: memberships);

  void stubRoster(MembershipStatus status, List<LobbyMember> members) => when(
    () => memberships.members(_lobbyId, status: status),
  ).thenAnswer((_) async => members);

  void stubEveryRoster() {
    stubRoster(MembershipStatus.approved, _approved);
    stubRoster(MembershipStatus.pending, _pending);
    stubRoster(MembershipStatus.banned, const []);
  }

  group('loading', () {
    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'reads the approved roster first',
      setUp: stubEveryRoster,
      build: build,
      act: (bloc) => bloc.add(const LobbyMembersRequested()),
      verify: (bloc) {
        expect(bloc.state.filter, MembershipStatus.approved);
        expect(bloc.state.visible, _approved);
        verify(
          () =>
              memberships.members(_lobbyId, status: MembershipStatus.approved),
        ).called(1);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'reads a roster the first time its filter is chosen',
      setUp: stubEveryRoster,
      build: build,
      act: (bloc) => bloc
        ..add(const LobbyMembersRequested())
        ..add(const LobbyMembersFilterChanged(MembershipStatus.pending)),
      verify: (bloc) {
        expect(bloc.state.filter, MembershipStatus.pending);
        expect(bloc.state.visible, _pending);
        // Both rosters are kept, so going back is free.
        expect(bloc.state.countOf(MembershipStatus.approved), 2);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'does not re-read a roster it already has',
      setUp: stubEveryRoster,
      build: build,
      act: (bloc) => bloc
        ..add(const LobbyMembersRequested())
        ..add(const LobbyMembersFilterChanged(MembershipStatus.pending))
        ..add(const LobbyMembersFilterChanged(MembershipStatus.approved)),
      verify: (_) => verify(
        () => memberships.members(_lobbyId, status: MembershipStatus.approved),
      ).called(1),
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'reads it again when asked to refresh',
      setUp: stubEveryRoster,
      build: build,
      act: (bloc) => bloc
        ..add(const LobbyMembersRequested())
        ..add(const LobbyMembersRefreshed()),
      verify: (_) => verify(
        () => memberships.members(_lobbyId, status: MembershipStatus.approved),
      ).called(2),
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'reports a roster it cannot read, with nothing to fall back on',
      setUp: () => when(
        () => memberships.members(_lobbyId, status: any(named: 'status')),
      ).thenThrow(const ApiException('Admins only.', code: 'admin_only')),
      build: build,
      act: (bloc) => bloc.add(const LobbyMembersRequested()),
      verify: (bloc) {
        expect(bloc.state.visible, isNull);
        expect(bloc.state.errorCode, 'admin_only');
        expect(bloc.state.isLoadingVisible, isFalse);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'tells an empty roster apart from one it has not read',
      setUp: stubEveryRoster,
      build: build,
      act: (bloc) =>
          bloc.add(const LobbyMembersFilterChanged(MembershipStatus.banned)),
      verify: (bloc) {
        // `[]` means "read it, nobody there" and shows an empty state; `null`
        // would still be a spinner.
        expect(bloc.state.visible, isEmpty);
        expect(bloc.state.visible, isNotNull);
      },
    );
  });

  group('actions', () {
    setUp(() {
      stubEveryRoster();
      when(
        () => memberships.approve(any(), any()),
      ).thenAnswer((_) async => _membership(MembershipStatus.approved));
      when(
        () => memberships.ban(any(), any()),
      ).thenAnswer((_) async => _membership(MembershipStatus.banned));
      when(() => memberships.reject(any(), any())).thenAnswer((_) async {});
      when(() => memberships.remove(any(), any())).thenAnswer((_) async {});
    });

    /// Loads the roster, then acts on the second row of it.
    Future<void> act(LobbyMembersBloc bloc, LobbyMemberAction action) async {
      bloc.add(const LobbyMembersRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(LobbyMemberActionRequested(userId: _userId, action: action));
    }

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'takes the row off the roster it was on',
      build: build,
      act: (bloc) => act(bloc, LobbyMemberAction.ban),
      verify: (bloc) {
        expect(bloc.state.visible, hasLength(1));
        expect(bloc.state.visible!.single.user.id, 'u1');
        verify(() => memberships.ban(_lobbyId, _userId)).called(1);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'drops the other rosters rather than guessing what happened to them',
      build: build,
      act: (bloc) async {
        bloc.add(const LobbyMembersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LobbyMembersFilterChanged(MembershipStatus.pending));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const LobbyMemberActionRequested(
            userId: _userId,
            action: LobbyMemberAction.approve,
          ),
        );
      },
      verify: (bloc) {
        // The approved roster gained a member server-side. Rather than patch a
        // guess in, it is dropped and re-read on the way back.
        expect(bloc.state.countOf(MembershipStatus.approved), isNull);
        expect(bloc.state.visible, isEmpty);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'names the person in the outcome, so the page can confirm it',
      build: build,
      act: (bloc) => act(bloc, LobbyMemberAction.remove),
      verify: (bloc) {
        expect(bloc.state.outcome?.memberName, 'climber');
        expect(bloc.state.outcome?.action, LobbyMemberAction.remove);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'marks only the row it is acting on as busy',
      build: build,
      act: (bloc) => act(bloc, LobbyMemberAction.ban),
      // The state after the roster loads and the action starts, before it
      // lands: the rest of the roster has to stay usable.
      skip: 2,
      expect: () => [
        isA<LobbyMembersState>()
            .having((s) => s.isBusy(_userId), 'the target is busy', isTrue)
            .having((s) => s.isBusy('u1'), 'nobody else is', isFalse),
        isA<LobbyMembersState>().having(
          (s) => s.busyUserIds,
          'busy rows once it lands',
          isEmpty,
        ),
      ],
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'ignores a second press while the first is in flight',
      build: build,
      act: (bloc) async {
        bloc.add(const LobbyMembersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(
            const LobbyMemberActionRequested(
              userId: _userId,
              action: LobbyMemberAction.ban,
            ),
          )
          ..add(
            const LobbyMemberActionRequested(
              userId: _userId,
              action: LobbyMemberAction.ban,
            ),
          );
      },
      verify: (_) => verify(() => memberships.ban(_lobbyId, _userId)).called(1),
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'keeps the row and reports a failure that leaves it in place',
      setUp: () => when(
        () => memberships.ban(any(), any()),
      ).thenThrow(const ApiException('No internet connection.')),
      build: build,
      act: (bloc) => act(bloc, LobbyMemberAction.ban),
      verify: (bloc) {
        expect(bloc.state.visible, hasLength(2));
        expect(bloc.state.errorMessage, 'No internet connection.');
        expect(bloc.state.outcome, isNull);
        expect(bloc.state.busyUserIds, isEmpty);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'drops a row another admin already dealt with',
      setUp: () => when(() => memberships.approve(any(), any())).thenThrow(
        const ApiException(
          'No such membership request.',
          statusCode: 404,
          code: 'member_not_found',
        ),
      ),
      build: build,
      act: (bloc) => act(bloc, LobbyMemberAction.approve),
      verify: (bloc) {
        // Leaving it on the list would invite the admin to press the same
        // button and get the same error.
        expect(bloc.state.visible, hasLength(1));
        expect(bloc.state.errorCode, 'member_not_found');
        // Nothing this admin did, so nothing is confirmed to them.
        expect(bloc.state.outcome, isNull);
      },
    );

    blocTest<LobbyMembersBloc, LobbyMembersState>(
      'does nothing for somebody who is not on the roster',
      build: build,
      act: (bloc) async {
        bloc.add(const LobbyMembersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const LobbyMemberActionRequested(
            userId: 'someone-else',
            action: LobbyMemberAction.ban,
          ),
        );
      },
      verify: (_) => verifyNever(() => memberships.ban(any(), any())),
    );
  });
}

Membership _membership(MembershipStatus status) =>
    Membership(lobbyId: _lobbyId, userId: _userId, status: status);
