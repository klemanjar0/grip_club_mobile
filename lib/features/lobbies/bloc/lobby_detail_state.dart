part of 'lobby_detail_bloc.dart';

enum LobbyDetailStatus { initial, loading, ready, failure }

/// What just happened, so the view can show the right confirmation once.
enum LobbyDetailOutcome { joined, requestSent, left, requestWithdrawn, deleted }

class LobbyDetailState extends Equatable {
  const LobbyDetailState({
    this.status = LobbyDetailStatus.initial,
    this.lobby,
    this.isActing = false,
    this.errorMessage,
    this.errorCode,
    this.outcome,
    this.accessLost = false,
    this.isRestricted = false,
  });

  final LobbyDetailStatus status;
  final Lobby? lobby;

  /// A join, leave or delete is in flight.
  final bool isActing;

  final String? errorMessage;

  /// `banned`, `already_member`, `request_pending`, `creator_cannot_leave`, …
  /// Switch on this, never on [errorMessage].
  final String? errorCode;

  final LobbyDetailOutcome? outcome;

  /// The lobby is no longer readable by the caller — they left a private lobby.
  /// The view pops back to the feed.
  final bool accessLost;

  /// The lobby exists but is closed to the caller (`403 not_a_member`) and no
  /// copy of it came from a feed. Survives the transient error fields, which a
  /// join clears: the page has to keep offering the way in.
  final bool isRestricted;

  bool get isLoading => status == LobbyDetailStatus.loading;

  LobbyDetailState copyWith({
    LobbyDetailStatus? status,
    Lobby? lobby,
    bool? isActing,
    String? errorMessage,
    String? errorCode,
    LobbyDetailOutcome? outcome,
    bool? accessLost,
    bool? isRestricted,
    bool clearError = false,
    bool clearOutcome = false,
  }) => LobbyDetailState(
    status: status ?? this.status,
    lobby: lobby ?? this.lobby,
    isActing: isActing ?? this.isActing,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    outcome: clearOutcome ? null : outcome ?? this.outcome,
    accessLost: accessLost ?? this.accessLost,
    isRestricted: isRestricted ?? this.isRestricted,
  );

  @override
  List<Object?> get props => [
    status,
    lobby,
    isActing,
    errorMessage,
    errorCode,
    outcome,
    accessLost,
    isRestricted,
  ];
}
