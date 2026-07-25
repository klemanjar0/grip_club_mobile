import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';

part 'lobby_detail_event.dart';
part 'lobby_detail_state.dart';

/// One lobby, plus the join / leave actions on it.
///
/// After a successful join or leave the lobby is re-fetched rather than patched
/// locally: `viewer.role`, `approved_count`, `address` and `chat_link` all
/// change server-side, and guessing them here would drift from the API.
class LobbyDetailBloc extends Bloc<LobbyDetailEvent, LobbyDetailState> {
  LobbyDetailBloc({
    required this.lobbyId,
    required this._lobbies,
    required this._memberships,
  }) : super(const LobbyDetailState()) {
    on<LobbyDetailRequested>(_onRequested);
    on<LobbyDetailJoinRequested>(_onJoinRequested);
    on<LobbyDetailLeaveRequested>(_onLeaveRequested);
  }

  final String lobbyId;
  final LobbyRepository _lobbies;
  final MembershipRepository _memberships;

  Future<void> _onRequested(
    LobbyDetailRequested event,
    Emitter<LobbyDetailState> emit,
  ) async {
    emit(state.copyWith(status: LobbyDetailStatus.loading, clearError: true));

    try {
      emit(
        state.copyWith(
          status: LobbyDetailStatus.ready,
          lobby: await _lobbies.byId(lobbyId),
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: LobbyDetailStatus.failure,
          errorMessage: exception.message,
          errorCode: exception.code,
        ),
      );
    }
  }

  Future<void> _onJoinRequested(
    LobbyDetailJoinRequested event,
    Emitter<LobbyDetailState> emit,
  ) async {
    if (state.isActing) return;

    emit(state.copyWith(isActing: true, clearError: true, clearOutcome: true));

    try {
      final membership = await _memberships.join(lobbyId);

      await _reload(
        emit,
        outcome: membership.isApproved
            ? LobbyDetailOutcome.joined
            : LobbyDetailOutcome.requestSent,
      );
    } on ApiException catch (exception) {
      emit(_actionFailed(exception));
    }
  }

  Future<void> _onLeaveRequested(
    LobbyDetailLeaveRequested event,
    Emitter<LobbyDetailState> emit,
  ) async {
    if (state.isActing) return;

    final wasPending = state.lobby?.viewer.isPending ?? false;

    emit(state.copyWith(isActing: true, clearError: true, clearOutcome: true));

    try {
      await _memberships.leave(lobbyId);

      await _reload(
        emit,
        outcome: wasPending
            ? LobbyDetailOutcome.requestWithdrawn
            : LobbyDetailOutcome.left,
      );
    } on ApiException catch (exception) {
      emit(_actionFailed(exception));
    }
  }

  /// Re-reads the lobby after a membership change.
  ///
  /// Leaving a private lobby costs the caller their access, so the refetch
  /// comes back `403 not_a_member`. That is the expected outcome, not a
  /// failure: the previous lobby stays on screen and the view pops.
  Future<void> _reload(
    Emitter<LobbyDetailState> emit, {
    required LobbyDetailOutcome outcome,
  }) async {
    try {
      emit(
        state.copyWith(
          status: LobbyDetailStatus.ready,
          lobby: await _lobbies.byId(lobbyId),
          isActing: false,
          outcome: outcome,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isActing: false,
          outcome: outcome,
          accessLost: exception.code == 'not_a_member',
        ),
      );
    }
  }

  LobbyDetailState _actionFailed(ApiException exception) => state.copyWith(
    isActing: false,
    errorMessage: exception.message,
    errorCode: exception.code,
  );
}
