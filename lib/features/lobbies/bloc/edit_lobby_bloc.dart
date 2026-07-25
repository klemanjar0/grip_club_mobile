import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

part 'edit_lobby_event.dart';
part 'edit_lobby_state.dart';

/// Backs the edit form for a lobby's admin.
///
/// Loads the lobby (or takes the copy the caller already had), then sends only
/// what actually changed. Diffing here rather than in the form is what makes
/// `PATCH /lobbies/{id}` behave like a partial update: an untouched field is
/// never in the body, so it cannot overwrite an edit made elsewhere, and a
/// lobby whose event time has already passed stays editable as long as the
/// admin does not touch the time (the server only rejects an `event_time` that
/// is present and not in the future).
class EditLobbyBloc extends Bloc<EditLobbyEvent, EditLobbyState> {
  EditLobbyBloc({
    required this.lobbyId,
    required this._repository,
    Lobby? initialLobby,
  }) : super(
         initialLobby == null
             ? const EditLobbyState()
             : EditLobbyState(lobby: initialLobby),
       ) {
    on<EditLobbyStarted>(_onStarted);
    on<EditLobbySubmitted>(_onSubmitted);
  }

  final String lobbyId;
  final LobbyRepository _repository;

  Future<void> _onStarted(
    EditLobbyStarted event,
    Emitter<EditLobbyState> emit,
  ) async {
    // Opened from the lobby page, which already has it: nothing to fetch.
    if (state.lobby != null) return;

    emit(state.copyWith(isLoading: true, clearFeedback: true));

    try {
      emit(
        state.copyWith(
          isLoading: false,
          lobby: await _repository.byId(lobbyId),
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(isLoading: false, errorMessage: exception.message));
    }
  }

  Future<void> _onSubmitted(
    EditLobbySubmitted event,
    Emitter<EditLobbyState> emit,
  ) async {
    final current = state.lobby;
    if (current == null || state.isSubmitting) return;

    final draft = event.draft;

    // Nothing to send. Saving anyway would notify every member of a change
    // that did not happen.
    if (draft == LobbyDraft.of(current)) {
      emit(state.copyWith(savedLobby: current, hasChanges: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearFeedback: true));

    try {
      final saved = await _repository.update(
        lobbyId,
        name: _changed(draft.name, current.name),
        country: _changed(draft.country, current.country),
        city: _changed(draft.city, current.city),
        eventTime:
            draft.eventTime.isAtSameMomentAs(
              current.eventTime ?? draft.eventTime,
            )
            ? null
            : draft.eventTime,
        visibility: draft.visibility == current.visibility
            ? null
            : draft.visibility,
        // These three are clearable: emptying one has to travel as an explicit
        // null, which is what `Optional` carries.
        description: _clearable(draft.description, current.description),
        address: _clearable(draft.address, current.address),
        chatLink: _clearable(draft.chatLink, current.chatLink),
      );

      emit(
        state.copyWith(
          isSubmitting: false,
          lobby: saved,
          savedLobby: saved,
          hasChanges: true,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: exception.message,
          errorCode: exception.code,
          fieldErrors: exception.fieldErrors,
        ),
      );
    }
  }

  /// `null` — the key is left out of the body — when the value is untouched.
  static String? _changed(String next, String current) =>
      next == current ? null : next;

  static Optional<String>? _clearable(String? next, String? current) =>
      next == current ? null : Optional<String>(next);
}
