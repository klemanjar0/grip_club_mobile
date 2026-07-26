import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';

part 'join_request_event.dart';
part 'join_request_state.dart';

/// One admin verdict on one pending join request.
///
/// Scoped to the sheet that shows it, so there is no reload and no feed here:
/// the request is identified entirely by [lobbyId] and [userId], both of which
/// the `join_request` notification carries. The sheet closes on [state.decision]
/// and the caller acts on it.
class JoinRequestBloc extends Bloc<JoinRequestEvent, JoinRequestState> {
  // Private field formal: callers still pass `memberships:`.
  JoinRequestBloc({
    required this.lobbyId,
    required this.userId,
    required this._memberships,
  }) : super(const JoinRequestState()) {
    on<JoinRequestApprovalRequested>(_onApprovalRequested);
    on<JoinRequestRejectionRequested>(_onRejectionRequested);
  }

  final String lobbyId;
  final String userId;
  final MembershipRepository _memberships;

  Future<void> _onApprovalRequested(
    JoinRequestApprovalRequested event,
    Emitter<JoinRequestState> emit,
  ) => _decide(emit, JoinRequestDecision.approved, () async {
    await _memberships.approve(lobbyId, userId);
  });

  Future<void> _onRejectionRequested(
    JoinRequestRejectionRequested event,
    Emitter<JoinRequestState> emit,
  ) => _decide(
    emit,
    JoinRequestDecision.rejected,
    () => _memberships.reject(lobbyId, userId),
  );

  /// Both verdicts are the same shape: one call, then either the decision or a
  /// message. Nothing is optimistic — the sheet stays open until the server has
  /// agreed, because a second admin may have answered first.
  Future<void> _decide(
    Emitter<JoinRequestState> emit,
    JoinRequestDecision decision,
    Future<void> Function() send,
  ) async {
    if (state.isSubmitting || state.decision != null) return;

    emit(
      state.copyWith(isSubmitting: true, pending: decision, clearError: true),
    );

    try {
      await send();

      emit(state.copyWith(isSubmitting: false, decision: decision));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isSubmitting: false,
          clearPending: true,
          errorMessage: exception.message,
          errorCode: exception.code,
        ),
      );
    }
  }
}
