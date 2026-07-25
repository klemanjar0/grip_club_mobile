part of 'create_lobby_bloc.dart';

class CreateLobbyState extends Equatable {
  const CreateLobbyState({
    this.isSubmitting = false,
    this.createdLobby,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  const CreateLobbyState.submitting() : this(isSubmitting: true);

  const CreateLobbyState.success(Lobby lobby) : this(createdLobby: lobby);

  const CreateLobbyState.failure({
    required String errorMessage,
    Map<String, String> fieldErrors = const {},
  }) : this(errorMessage: errorMessage, fieldErrors: fieldErrors);

  final bool isSubmitting;

  /// Non-null once the lobby exists; the view pops and opens it.
  final Lobby? createdLobby;

  final String? errorMessage;

  /// From `validation_failed`, keyed by JSON field name (`name`, `event_time`,
  /// …). The form maps these onto its own fields.
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [
    isSubmitting,
    createdLobby,
    errorMessage,
    fieldErrors,
  ];
}
