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
///
/// [initialLobby] is the copy the feed already had. `GET /lobbies/{id}` answers
/// `403 not_a_member` to outsiders and pending applicants, so without it there
/// would be nothing to show the very people who still need to join.
class LobbyDetailBloc extends Bloc<LobbyDetailEvent, LobbyDetailState> {
  LobbyDetailBloc({
    required this.lobbyId,
    required this._lobbies,
    required this._memberships,
    Lobby? initialLobby,
  }) : super(
         initialLobby == null
             ? const LobbyDetailState()
             : LobbyDetailState(
                 status: LobbyDetailStatus.ready,
                 lobby: initialLobby,
               ),
       ) {
    on<LobbyDetailRequested>(_onRequested);
    on<LobbyDetailUpdated>(
      (event, emit) => emit(
        state.copyWith(status: LobbyDetailStatus.ready, lobby: event.lobby),
      ),
    );
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
      // Being locked out is not worth reporting when the feed's copy is in
      // hand: the page renders from that, and `viewer.can_join` still drives
      // the join button. Only a first load with nothing behind it is a failure
      // — and the view turns a bare `not_a_member` into a join prompt rather
      // than a retry button.
      if (state.lobby != null) {
        emit(state.copyWith(status: LobbyDetailStatus.ready));
        return;
      }

      emit(
        state.copyWith(
          status: LobbyDetailStatus.failure,
          errorMessage: exception.message,
          errorCode: exception.code,
          isRestricted: exception.code == 'not_a_member',
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
      final outcome = membership.isApproved
          ? LobbyDetailOutcome.joined
          : LobbyDetailOutcome.requestSent;

      try {
        emit(
          state.copyWith(
            status: LobbyDetailStatus.ready,
            lobby: await _lobbies.byId(lobbyId),
            isActing: false,
            outcome: outcome,
          ),
        );
      } on ApiException {
        // Requesting to join a private lobby leaves the caller *pending*, and
        // `GET /lobbies/{id}` says `403` to a pending applicant — there is
        // nothing to re-read. Patch the copy on screen instead; unlike leaving,
        // this is not a reason to close the page. With no copy to patch the
        // page stays on its members-only state, which now reads as pending.
        final current = state.lobby;

        emit(
          state.copyWith(
            status: current == null
                ? LobbyDetailStatus.failure
                : LobbyDetailStatus.ready,
            lobby: current?.withMembership(membership.status),
            isActing: false,
            outcome: outcome,
          ),
        );
      }
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

  /// Re-reads the lobby after leaving it.
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
