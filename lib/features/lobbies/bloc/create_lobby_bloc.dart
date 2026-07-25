import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

part 'create_lobby_event.dart';
part 'create_lobby_state.dart';

/// Backs the create-lobby form.
///
/// Client-side validation happens in the form; this bloc exists to run the
/// request and to translate a server-side `validation_failed` back onto the
/// fields, the same way the register form does.
class CreateLobbyBloc extends Bloc<CreateLobbyEvent, CreateLobbyState> {
  CreateLobbyBloc({required this._repository})
    : super(const CreateLobbyState()) {
    on<CreateLobbySubmitted>(_onSubmitted);
  }

  final LobbyRepository _repository;

  Future<void> _onSubmitted(
    CreateLobbySubmitted event,
    Emitter<CreateLobbyState> emit,
  ) async {
    emit(const CreateLobbyState.submitting());

    try {
      final lobby = await _repository.create(
        name: event.name,
        country: event.country,
        city: event.city,
        eventTime: event.eventTime,
        visibility: event.visibility,
        description: event.description,
        address: event.address,
        chatLink: event.chatLink,
      );

      emit(CreateLobbyState.success(lobby));
    } on ApiException catch (exception) {
      emit(
        CreateLobbyState.failure(
          errorMessage: exception.message,
          fieldErrors: exception.fieldErrors,
        ),
      );
    }
  }
}
