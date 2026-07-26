import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/bloc/join_request_bloc.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

class _MockMembershipRepository extends Mock implements MembershipRepository {}

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';
const _userId = 'u0000000-0000-4000-8000-000000000001';

final _approved = Membership(
  lobbyId: _lobbyId,
  userId: _userId,
  status: MembershipStatus.approved,
  joinedAt: DateTime.utc(2026, 8, 24),
);

void main() {
  late MembershipRepository memberships;

  setUp(() => memberships = _MockMembershipRepository());

  JoinRequestBloc build() => JoinRequestBloc(
    lobbyId: _lobbyId,
    userId: _userId,
    memberships: memberships,
  );

  group('JoinRequestApprovalRequested', () {
    blocTest<JoinRequestBloc, JoinRequestState>(
      'approves and settles on the decision',
      setUp: () => when(
        () => memberships.approve(_lobbyId, _userId),
      ).thenAnswer((_) async => _approved),
      build: build,
      act: (bloc) => bloc.add(const JoinRequestApprovalRequested()),
      expect: () => const [
        JoinRequestState(
          isSubmitting: true,
          pending: JoinRequestDecision.approved,
        ),
        JoinRequestState(
          pending: JoinRequestDecision.approved,
          decision: JoinRequestDecision.approved,
        ),
      ],
      verify: (_) => verify(() => memberships.approve(_lobbyId, _userId)),
    );

    blocTest<JoinRequestBloc, JoinRequestState>(
      'a failure clears the spinner and keeps the buttons live',
      setUp: () => when(() => memberships.approve(_lobbyId, _userId)).thenThrow(
        const ApiException(
          'Only the organizer can do that.',
          statusCode: 403,
          code: 'admin_only',
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const JoinRequestApprovalRequested()),
      skip: 1,
      expect: () => const [
        JoinRequestState(
          errorMessage: 'Only the organizer can do that.',
          errorCode: 'admin_only',
        ),
      ],
    );

    blocTest<JoinRequestBloc, JoinRequestState>(
      'flags member_not_found as settled elsewhere rather than a plain error',
      setUp: () => when(() => memberships.approve(_lobbyId, _userId)).thenThrow(
        const ApiException(
          'No such membership request.',
          statusCode: 404,
          code: 'member_not_found',
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const JoinRequestApprovalRequested()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.isSettledElsewhere, isTrue);
        // Not a decision — nobody was let in or turned away here.
        expect(bloc.state.decision, isNull);
      },
    );

    blocTest<JoinRequestBloc, JoinRequestState>(
      'ignores a second tap while the first is in flight',
      setUp: () => when(
        () => memberships.approve(_lobbyId, _userId),
      ).thenAnswer((_) async => _approved),
      build: build,
      seed: () => const JoinRequestState(isSubmitting: true),
      act: (bloc) => bloc.add(const JoinRequestApprovalRequested()),
      expect: () => <JoinRequestState>[],
      verify: (_) => verifyNever(() => memberships.approve(any(), any())),
    );

    blocTest<JoinRequestBloc, JoinRequestState>(
      'refuses to act again once the request is settled',
      setUp: () => when(
        () => memberships.approve(_lobbyId, _userId),
      ).thenAnswer((_) async => _approved),
      build: build,
      seed: () =>
          const JoinRequestState(decision: JoinRequestDecision.rejected),
      act: (bloc) => bloc.add(const JoinRequestApprovalRequested()),
      expect: () => <JoinRequestState>[],
      verify: (_) => verifyNever(() => memberships.approve(any(), any())),
    );
  });

  group('JoinRequestRejectionRequested', () {
    blocTest<JoinRequestBloc, JoinRequestState>(
      'declines and settles on the decision',
      setUp: () => when(
        () => memberships.reject(_lobbyId, _userId),
      ).thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(const JoinRequestRejectionRequested()),
      expect: () => const [
        JoinRequestState(
          isSubmitting: true,
          pending: JoinRequestDecision.rejected,
        ),
        JoinRequestState(
          pending: JoinRequestDecision.rejected,
          decision: JoinRequestDecision.rejected,
        ),
      ],
      verify: (_) {
        verify(() => memberships.reject(_lobbyId, _userId));
        // Declining is not banning — the row is deleted so they may re-apply.
        verifyNever(() => memberships.approve(any(), any()));
      },
    );
  });
}
