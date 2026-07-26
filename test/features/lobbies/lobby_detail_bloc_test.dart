import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_detail_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

import '../../helpers/lobby_fixtures.dart';

class _MockLobbyRepository extends Mock implements LobbyRepository {}

class _MockMembershipRepository extends Mock implements MembershipRepository {}

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';

final _asOutsider = lobby();
final _asMember = lobby(role: 'member', canJoin: false);
final _asPending = lobby(role: 'pending', canJoin: false);
final _asAdmin = lobby(role: 'admin', canJoin: false);

Membership _membership(MembershipStatus status) => Membership(
  lobbyId: _lobbyId,
  userId: 'u1',
  status: status,
  joinedAt: DateTime.utc(2026, 8, 24),
);

void main() {
  late LobbyRepository lobbies;
  late MembershipRepository memberships;

  setUp(() {
    lobbies = _MockLobbyRepository();
    memberships = _MockMembershipRepository();
  });

  LobbyDetailBloc build() => LobbyDetailBloc(
    lobbyId: _lobbyId,
    lobbies: lobbies,
    memberships: memberships,
  );

  group('LobbyDetailRequested', () {
    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'loads the lobby',
      setUp: () => when(
        () => lobbies.byId(_lobbyId),
      ).thenAnswer((_) async => _asOutsider),
      build: build,
      act: (bloc) => bloc.add(const LobbyDetailRequested()),
      expect: () => [
        const LobbyDetailState(status: LobbyDetailStatus.loading),
        LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asOutsider),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'flags a 403 as restricted rather than as a failure to retry',
      setUp: () => when(() => lobbies.byId(_lobbyId)).thenThrow(
        const ApiException(
          'Join the lobby to see its details.',
          statusCode: 403,
          code: 'not_a_member',
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const LobbyDetailRequested()),
      expect: () => const [
        LobbyDetailState(status: LobbyDetailStatus.loading),
        LobbyDetailState(
          status: LobbyDetailStatus.failure,
          errorMessage: 'Join the lobby to see its details.',
          errorCode: 'not_a_member',
          isRestricted: true,
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'a 404 is a plain failure, not a restriction',
      setUp: () => when(() => lobbies.byId(_lobbyId)).thenThrow(
        const ApiException(
          'No such lobby.',
          statusCode: 404,
          code: 'lobby_not_found',
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const LobbyDetailRequested()),
      skip: 1,
      expect: () => const [
        LobbyDetailState(
          status: LobbyDetailStatus.failure,
          errorMessage: 'No such lobby.',
          errorCode: 'lobby_not_found',
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'keeps the feed\'s copy when the server locks the caller out',
      setUp: () => when(() => lobbies.byId(_lobbyId)).thenThrow(
        const ApiException(
          'Join the lobby to see its details.',
          statusCode: 403,
          code: 'not_a_member',
        ),
      ),
      build: () => LobbyDetailBloc(
        lobbyId: _lobbyId,
        lobbies: lobbies,
        memberships: memberships,
        initialLobby: _asOutsider,
      ),
      act: (bloc) => bloc.add(const LobbyDetailRequested()),
      // The page stays readable and no error reaches the reader: the copy from
      // the list is exactly what they were already looking at.
      expect: () => [
        LobbyDetailState(status: LobbyDetailStatus.loading, lobby: _asOutsider),
        LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asOutsider),
      ],
    );
  });

  group('LobbyDetailJoinRequested', () {
    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'a public lobby approves immediately and the lobby is re-read',
      setUp: () {
        when(
          () => memberships.join(_lobbyId),
        ).thenAnswer((_) async => _membership(MembershipStatus.approved));
        when(() => lobbies.byId(_lobbyId)).thenAnswer((_) async => _asMember);
      },
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asOutsider),
      act: (bloc) => bloc.add(const LobbyDetailJoinRequested()),
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asOutsider,
          isActing: true,
        ),
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asMember,
          outcome: LobbyDetailOutcome.joined,
        ),
      ],
      // The refetch is the point: role, approved_count, address and chat_link
      // all change server-side on a join.
      verify: (_) => verify(() => lobbies.byId(_lobbyId)).called(1),
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'a private lobby only leaves a pending request',
      setUp: () {
        when(
          () => memberships.join(_lobbyId),
        ).thenAnswer((_) async => _membership(MembershipStatus.pending));
        when(() => lobbies.byId(_lobbyId)).thenAnswer((_) async => _asPending);
      },
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asOutsider),
      act: (bloc) => bloc.add(const LobbyDetailJoinRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asPending,
          outcome: LobbyDetailOutcome.requestSent,
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'surfaces banned without touching the loaded lobby',
      setUp: () => when(() => memberships.join(_lobbyId)).thenThrow(
        const ApiException(
          'You are banned from this lobby.',
          statusCode: 403,
          code: 'banned',
        ),
      ),
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asOutsider),
      act: (bloc) => bloc.add(const LobbyDetailJoinRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asOutsider,
          errorMessage: 'You are banned from this lobby.',
          errorCode: 'banned',
        ),
      ],
      verify: (_) => verifyNever(() => lobbies.byId(any())),
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'ignores a second tap while the first is in flight',
      setUp: () {
        when(
          () => memberships.join(_lobbyId),
        ).thenAnswer((_) async => _membership(MembershipStatus.approved));
        when(() => lobbies.byId(_lobbyId)).thenAnswer((_) async => _asMember);
      },
      build: build,
      seed: () => LobbyDetailState(
        status: LobbyDetailStatus.ready,
        lobby: _asOutsider,
        isActing: true,
      ),
      act: (bloc) => bloc.add(const LobbyDetailJoinRequested()),
      expect: () => <LobbyDetailState>[],
      verify: (_) => verifyNever(() => memberships.join(any())),
    );
  });

  group('LobbyDetailLeaveRequested', () {
    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'leaving a private lobby costs the read access, and that is not an error',
      setUp: () {
        when(() => memberships.leave(_lobbyId)).thenAnswer((_) async {});
        when(() => lobbies.byId(_lobbyId)).thenThrow(
          const ApiException(
            'Join the lobby to see its details.',
            statusCode: 403,
            code: 'not_a_member',
          ),
        );
      },
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asMember),
      act: (bloc) => bloc.add(const LobbyDetailLeaveRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asMember,
          outcome: LobbyDetailOutcome.left,
          accessLost: true,
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'withdrawing a pending request reads as its own outcome',
      setUp: () {
        when(() => memberships.leave(_lobbyId)).thenAnswer((_) async {});
        when(() => lobbies.byId(_lobbyId)).thenAnswer((_) async => _asOutsider);
      },
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asPending),
      act: (bloc) => bloc.add(const LobbyDetailLeaveRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asOutsider,
          outcome: LobbyDetailOutcome.requestWithdrawn,
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'surfaces creator_cannot_leave',
      setUp: () => when(() => memberships.leave(_lobbyId)).thenThrow(
        const ApiException(
          'Delete the lobby instead.',
          statusCode: 403,
          code: 'creator_cannot_leave',
        ),
      ),
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asMember),
      act: (bloc) => bloc.add(const LobbyDetailLeaveRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asMember,
          errorCode: 'creator_cannot_leave',
          errorMessage: 'Delete the lobby instead.',
        ),
      ],
    );
  });

  group('LobbyDetailDeleteRequested', () {
    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'reports the deletion without re-reading the lobby',
      setUp: () =>
          when(() => lobbies.deleteLobby(_lobbyId)).thenAnswer((_) async {}),
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asAdmin),
      act: (bloc) => bloc.add(const LobbyDetailDeleteRequested()),
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asAdmin,
          isActing: true,
        ),
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asAdmin,
          outcome: LobbyDetailOutcome.deleted,
        ),
      ],
      // The lobby is gone — a refetch would only be a 404.
      verify: (_) => verifyNever(() => lobbies.byId(any())),
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'surfaces admin_only and keeps the lobby on screen',
      setUp: () => when(() => lobbies.deleteLobby(_lobbyId)).thenThrow(
        const ApiException(
          'Only the organizer can do that.',
          statusCode: 403,
          code: 'admin_only',
        ),
      ),
      build: build,
      seed: () =>
          LobbyDetailState(status: LobbyDetailStatus.ready, lobby: _asMember),
      act: (bloc) => bloc.add(const LobbyDetailDeleteRequested()),
      skip: 1,
      expect: () => [
        LobbyDetailState(
          status: LobbyDetailStatus.ready,
          lobby: _asMember,
          errorMessage: 'Only the organizer can do that.',
          errorCode: 'admin_only',
        ),
      ],
    );

    blocTest<LobbyDetailBloc, LobbyDetailState>(
      'ignores a second tap while the first is in flight',
      setUp: () =>
          when(() => lobbies.deleteLobby(_lobbyId)).thenAnswer((_) async {}),
      build: build,
      seed: () => LobbyDetailState(
        status: LobbyDetailStatus.ready,
        lobby: _asAdmin,
        isActing: true,
      ),
      act: (bloc) => bloc.add(const LobbyDetailDeleteRequested()),
      expect: () => <LobbyDetailState>[],
      verify: (_) => verifyNever(() => lobbies.deleteLobby(any())),
    );
  });
}
