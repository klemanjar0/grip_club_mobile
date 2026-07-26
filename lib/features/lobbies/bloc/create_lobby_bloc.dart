import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/files/data/avatar_uploader.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

part 'create_lobby_event.dart';
part 'create_lobby_state.dart';

/// Backs the create-lobby form.
///
/// Client-side validation happens in the form; this bloc exists to run the
/// request and to translate a server-side `validation_failed` back onto the
/// fields, the same way the register form does.
class CreateLobbyBloc extends Bloc<CreateLobbyEvent, CreateLobbyState> {
  CreateLobbyBloc({required this._repository, required this._avatars})
    : super(const CreateLobbyState()) {
    on<CreateLobbySubmitted>(_onSubmitted);
  }

  final LobbyRepository _repository;
  final AvatarUploader _avatars;

  Future<void> _onSubmitted(
    CreateLobbySubmitted event,
    Emitter<CreateLobbyState> emit,
  ) async {
    emit(const CreateLobbyState.submitting());

    try {
      // The picture is uploaded first and attached by id — a failure here
      // leaves no lobby behind, and an upload that is never attached is
      // reclaimed server-side.
      final avatarFileId = await _avatars.resolve(event.draft.avatar);

      emit(
        CreateLobbyState.success(
          await _repository.create(
            event.draft,
            avatarFileId: avatarFileId?.value,
          ),
        ),
      );
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
