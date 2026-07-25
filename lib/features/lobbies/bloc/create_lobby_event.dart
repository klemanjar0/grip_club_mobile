part of 'create_lobby_bloc.dart';

sealed class CreateLobbyEvent extends Equatable {
  const CreateLobbyEvent();

  @override
  List<Object?> get props => [];
}

final class CreateLobbySubmitted extends CreateLobbyEvent {
  const CreateLobbySubmitted(this.draft);

  final LobbyDraft draft;

  @override
  List<Object?> get props => [draft];
}
