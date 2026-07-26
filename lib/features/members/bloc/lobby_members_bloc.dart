import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';

part 'lobby_members_event.dart';
part 'lobby_members_state.dart';

/// The admin's view of one lobby's roster, and everything they can do to it.
///
/// The API serves one status at a time, so this holds one roster per status and
/// shows whichever [LobbyMembersState.filter] names. Rosters are cached as they
/// are visited — they are small and unpaginated, so a second look at a tab the
/// admin already opened costs nothing.
///
/// Nothing here is optimistic. An action is only reflected once the server has
/// agreed, because two admins can act on the same person, and because the
/// consequences — a notification, a ban that cannot be undone — are real.
class LobbyMembersBloc extends Bloc<LobbyMembersEvent, LobbyMembersState> {
  LobbyMembersBloc({required this.lobbyId, required this._memberships})
    : super(const LobbyMembersState()) {
    on<LobbyMembersRequested>((event, emit) => _load(emit, state.filter));
    on<LobbyMembersFilterChanged>(_onFilterChanged);
    on<LobbyMembersRefreshed>(
      (event, emit) => _load(emit, state.filter, force: true),
    );
    on<LobbyMemberActionRequested>(_onActionRequested);
  }

  final String lobbyId;
  final MembershipRepository _memberships;

  Future<void> _onFilterChanged(
    LobbyMembersFilterChanged event,
    Emitter<LobbyMembersState> emit,
  ) async {
    if (event.filter == state.filter) return;

    // The message under the old roster does not describe the new one.
    emit(state.copyWith(filter: event.filter, clearFeedback: true));

    await _load(emit, event.filter);
  }

  /// Reads one roster. A cached one is left alone unless [force] says otherwise
  /// — that is what makes switching back to a tab instant.
  Future<void> _load(
    Emitter<LobbyMembersState> emit,
    MembershipStatus status, {
    bool force = false,
  }) async {
    if (state.loading.contains(status)) return;
    if (!force && state.rosters.containsKey(status)) return;

    emit(
      state.copyWith(loading: {...state.loading, status}, clearFeedback: true),
    );

    try {
      final members = await _memberships.members(lobbyId, status: status);

      emit(
        state.copyWith(
          rosters: {...state.rosters, status: members},
          loading: state.loading.difference({status}),
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          loading: state.loading.difference({status}),
          errorMessage: exception.message,
          errorCode: exception.code,
        ),
      );
    }
  }

  /// Runs one verdict against one person.
  ///
  /// Whatever the action, the row leaves the roster it was on — an approved
  /// applicant is no longer pending, a banned member is no longer approved. The
  /// other rosters are dropped rather than patched: they are cheap to re-read
  /// and guessing what the server did to them is how a roster starts lying.
  Future<void> _onActionRequested(
    LobbyMemberActionRequested event,
    Emitter<LobbyMembersState> emit,
  ) async {
    if (state.isBusy(event.userId)) return;

    final member = _find(event.userId);
    if (member == null) return;

    emit(
      state.copyWith(
        busyUserIds: {...state.busyUserIds, event.userId},
        clearFeedback: true,
      ),
    );

    try {
      await _send(event.action, event.userId);

      emit(
        state.copyWith(
          rosters: {state.filter: _withoutUser(event.userId)},
          busyUserIds: state.busyUserIds.difference({event.userId}),
          outcome: LobbyMemberOutcome(
            action: event.action,
            memberName: member.user.displayName,
          ),
        ),
      );
    } on ApiException catch (exception) {
      // The row is already gone — withdrawn, or answered by another admin. Take
      // it off the roster anyway: leaving it there invites the admin to press
      // the same button again and get the same error.
      final isSettledElsewhere = exception.code == 'member_not_found';

      emit(
        state.copyWith(
          rosters: isSettledElsewhere
              ? {state.filter: _withoutUser(event.userId)}
              : null,
          busyUserIds: state.busyUserIds.difference({event.userId}),
          errorMessage: exception.message,
          errorCode: exception.code,
        ),
      );
    }
  }

  Future<void> _send(LobbyMemberAction action, String userId) async {
    switch (action) {
      case LobbyMemberAction.approve:
        await _memberships.approve(lobbyId, userId);
      case LobbyMemberAction.reject:
        await _memberships.reject(lobbyId, userId);
      case LobbyMemberAction.ban:
        await _memberships.ban(lobbyId, userId);
      case LobbyMemberAction.remove:
        await _memberships.remove(lobbyId, userId);
    }
  }

  LobbyMember? _find(String userId) {
    for (final member in state.visible ?? const <LobbyMember>[]) {
      if (member.user.id == userId) return member;
    }

    return null;
  }

  List<LobbyMember> _withoutUser(String userId) => [
    for (final member in state.visible ?? const <LobbyMember>[])
      if (member.user.id != userId) member,
  ];
}
