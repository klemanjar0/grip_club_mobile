import 'package:equatable/equatable.dart';

/// Events shared by both lobby feeds.
sealed class LobbyFeedEvent extends Equatable {
  const LobbyFeedEvent();

  @override
  List<Object?> get props => [];
}

/// First load. Re-dispatching is cheap: an already-loaded feed is left alone.
final class LobbyFeedRequested extends LobbyFeedEvent {
  const LobbyFeedRequested();
}

/// Pull-to-refresh, or an external change (a lobby was just created). Resets to
/// page 0 while keeping the current filters.
final class LobbyFeedRefreshed extends LobbyFeedEvent {
  const LobbyFeedRefreshed();
}

/// Fired repeatedly by the scroll listener; the bloc drops it while a page is
/// in flight or there is nothing more to fetch.
final class LobbyFeedNextPageRequested extends LobbyFeedEvent {
  const LobbyFeedNextPageRequested();
}

/// Drops everything loaded, filters included, and returns the feed to its
/// initial state. Dispatched on sign-out: these blocs outlive a session.
final class LobbyFeedCleared extends LobbyFeedEvent {
  const LobbyFeedCleared();
}

/// Browse feed only. `city: ''` means everywhere, overriding the saved city.
final class LobbyFeedFilterChanged extends LobbyFeedEvent {
  const LobbyFeedFilterChanged({this.city, this.within});

  final String? city;
  final String? within;

  @override
  List<Object?> get props => [city, within];
}
