part of 'edit_lobby_bloc.dart';

sealed class EditLobbyEvent extends Equatable {
  const EditLobbyEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the lobby, unless the caller already handed one over.
final class EditLobbyStarted extends EditLobbyEvent {
  const EditLobbyStarted();
}

/// The whole form as typed. What actually gets sent is the difference between
/// this and the stored lobby.
final class EditLobbySubmitted extends EditLobbyEvent {
  const EditLobbySubmitted(this.draft);

  final LobbyDraft draft;

  @override
  List<Object?> get props => [draft];
}
