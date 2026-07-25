import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

enum LobbyFeedStatus { initial, loading, ready, failure }

/// State shared by the two lobby feeds (`/lobbies` and `/me/lobbies`).
///
/// [page] is the last page successfully loaded, zero-based; the next request
/// asks for `page + 1`. [isLoadingMore] guards the infinite scroll — the view
/// fires "load more" on every qualifying scroll frame and this is what makes
/// the duplicates no-ops.
class LobbyFeedState extends Equatable {
  const LobbyFeedState({
    this.status = LobbyFeedStatus.initial,
    this.lobbies = const [],
    this.page = 0,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.city,
    this.within,
  });

  final LobbyFeedStatus status;
  final List<Lobby> lobbies;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;

  /// Set on a failed *first* page; a failed next page surfaces as a snackbar
  /// instead so the loaded list is not thrown away.
  final String? errorMessage;

  /// Active filters. `null` means "server default" (the user's saved
  /// preference); `''` for [city] means everywhere. Unused by the My Lobbies
  /// feed.
  final String? city;
  final String? within;

  bool get isEmpty => status == LobbyFeedStatus.ready && lobbies.isEmpty;

  LobbyFeedState copyWith({
    LobbyFeedStatus? status,
    List<Lobby>? lobbies,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? city,
    String? within,
  }) => LobbyFeedState(
    status: status ?? this.status,
    lobbies: lobbies ?? this.lobbies,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    city: city ?? this.city,
    within: within ?? this.within,
  );

  @override
  List<Object?> get props => [
    status,
    lobbies,
    page,
    hasNext,
    isLoadingMore,
    errorMessage,
    city,
    within,
  ];
}
