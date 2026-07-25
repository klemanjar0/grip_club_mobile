part of 'lobby_detail_bloc.dart';

sealed class LobbyDetailEvent extends Equatable {
  const LobbyDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Loads (or reloads) the lobby.
final class LobbyDetailRequested extends LobbyDetailEvent {
  const LobbyDetailRequested();
}

/// Public lobby → approved on the spot; private → a request the admin reviews.
final class LobbyDetailJoinRequested extends LobbyDetailEvent {
  const LobbyDetailJoinRequested();
}

/// Leaves the lobby, or withdraws a request that is still pending.
final class LobbyDetailLeaveRequested extends LobbyDetailEvent {
  const LobbyDetailLeaveRequested();
}
