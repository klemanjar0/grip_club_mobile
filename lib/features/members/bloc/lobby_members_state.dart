part of 'lobby_members_bloc.dart';

/// An action that landed, so the page can confirm it once by name.
class LobbyMemberOutcome extends Equatable {
  const LobbyMemberOutcome({required this.action, required this.memberName});

  final LobbyMemberAction action;
  final String memberName;

  @override
  List<Object?> get props => [action, memberName];
}

class LobbyMembersState extends Equatable {
  const LobbyMembersState({
    this.filter = MembershipStatus.approved,
    this.rosters = const {},
    this.loading = const {},
    this.busyUserIds = const {},
    this.errorMessage,
    this.errorCode,
    this.outcome,
  });

  /// Which roster is on screen. The API serves one status at a time.
  final MembershipStatus filter;

  /// The rosters that have been read, keyed by status. A missing key means "not
  /// loaded yet"; an empty list means "loaded, and nobody is in it" — a
  /// distinction the empty state depends on.
  final Map<MembershipStatus, List<LobbyMember>> rosters;

  /// Which rosters are in flight. A set rather than a flag so switching filters
  /// mid-load cannot leave a spinner attributed to the wrong list.
  final Set<MembershipStatus> loading;

  /// Rows with an action in flight, so only those show a spinner and the rest
  /// of the roster stays usable.
  final Set<String> busyUserIds;

  final String? errorMessage;

  /// `admin_only`, `member_not_found`, … Switch on this, never on the message.
  final String? errorCode;

  /// The last action that landed, so the page can confirm it by name.
  final LobbyMemberOutcome? outcome;

  List<LobbyMember>? get visible => rosters[filter];

  bool get isLoadingVisible => loading.contains(filter);

  /// The first load of the roster on screen: there is nothing to show under the
  /// spinner, unlike a refresh.
  bool get isLoadingFirstTime => isLoadingVisible && visible == null;

  bool isBusy(String userId) => busyUserIds.contains(userId);

  int? countOf(MembershipStatus status) => rosters[status]?.length;

  LobbyMembersState copyWith({
    MembershipStatus? filter,
    Map<MembershipStatus, List<LobbyMember>>? rosters,
    Set<MembershipStatus>? loading,
    Set<String>? busyUserIds,
    String? errorMessage,
    String? errorCode,
    LobbyMemberOutcome? outcome,
    bool clearFeedback = false,
  }) => LobbyMembersState(
    filter: filter ?? this.filter,
    rosters: rosters ?? this.rosters,
    loading: loading ?? this.loading,
    busyUserIds: busyUserIds ?? this.busyUserIds,
    errorMessage: clearFeedback ? null : errorMessage ?? this.errorMessage,
    errorCode: clearFeedback ? null : errorCode ?? this.errorCode,
    outcome: clearFeedback ? null : outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [
    filter,
    rosters,
    loading,
    busyUserIds,
    errorMessage,
    errorCode,
    outcome,
  ];
}
