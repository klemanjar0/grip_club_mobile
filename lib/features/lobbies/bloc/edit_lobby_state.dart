part of 'edit_lobby_bloc.dart';

class EditLobbyState extends Equatable {
  const EditLobbyState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.lobby,
    this.savedLobby,
    this.hasChanges = false,
    this.errorMessage,
    this.errorCode,
    this.fieldErrors = const {},
  });

  final bool isLoading;
  final bool isSubmitting;

  /// The lobby being edited — the form's starting values.
  final Lobby? lobby;

  /// Non-null once the edit is done; the page pops and hands it back.
  final Lobby? savedLobby;

  /// False when the save was a no-op because nothing was actually edited.
  final bool hasChanges;

  final String? errorMessage;

  /// `admin_only`, `lobby_not_found`, … Switch on this, never on the message.
  final String? errorCode;

  /// From `validation_failed`, keyed by JSON field name (`name`, `event_time`,
  /// …). The form places these on its own fields.
  final Map<String, String> fieldErrors;

  /// The lobby could not be loaded at all, so there is no form to show.
  bool get isUnavailable => lobby == null && !isLoading;

  EditLobbyState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    Lobby? lobby,
    Lobby? savedLobby,
    bool? hasChanges,
    String? errorMessage,
    String? errorCode,
    Map<String, String>? fieldErrors,
    bool clearFeedback = false,
  }) => EditLobbyState(
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    lobby: lobby ?? this.lobby,
    savedLobby: clearFeedback ? null : savedLobby ?? this.savedLobby,
    hasChanges: hasChanges ?? this.hasChanges,
    errorMessage: clearFeedback ? null : errorMessage ?? this.errorMessage,
    errorCode: clearFeedback ? null : errorCode ?? this.errorCode,
    fieldErrors: clearFeedback ? const {} : fieldErrors ?? this.fieldErrors,
  );

  @override
  List<Object?> get props => [
    isLoading,
    isSubmitting,
    lobby,
    savedLobby,
    hasChanges,
    errorMessage,
    errorCode,
    fieldErrors,
  ];
}
