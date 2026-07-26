part of 'lobby_members_bloc.dart';

/// What an admin can do to one person on the roster.
///
/// Four verbs rather than a status to set, because they are not
/// interchangeable: [reject] and [remove] delete the row and can be undone by
/// the person themselves, while [ban] leaves one behind and cannot.
enum LobbyMemberAction {
  approve,
  reject,
  ban,
  remove;

  /// What is on offer for a row in [status], in the order it should be shown.
  ///
  /// [remove] appears against a banned row too: it deletes the row, and a
  /// person with no row may join again — which is the only way back from a ban.
  static List<LobbyMemberAction> forStatus(MembershipStatus status) =>
      switch (status) {
        MembershipStatus.pending => const [
          LobbyMemberAction.approve,
          LobbyMemberAction.reject,
          LobbyMemberAction.ban,
        ],
        MembershipStatus.approved => const [
          LobbyMemberAction.remove,
          LobbyMemberAction.ban,
        ],
        MembershipStatus.banned => const [LobbyMemberAction.remove],
      };
}

sealed class LobbyMembersEvent extends Equatable {
  const LobbyMembersEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the roster on screen, unless it is already in hand.
final class LobbyMembersRequested extends LobbyMembersEvent {
  const LobbyMembersRequested();
}

/// Shows a different roster, loading it the first time it is asked for.
final class LobbyMembersFilterChanged extends LobbyMembersEvent {
  const LobbyMembersFilterChanged(this.filter);

  final MembershipStatus filter;

  @override
  List<Object?> get props => [filter];
}

/// Re-reads the roster on screen even though it is already loaded.
final class LobbyMembersRefreshed extends LobbyMembersEvent {
  const LobbyMembersRefreshed();
}

/// Runs [action] against one person.
final class LobbyMemberActionRequested extends LobbyMembersEvent {
  const LobbyMemberActionRequested({
    required this.userId,
    required this.action,
  });

  final String userId;
  final LobbyMemberAction action;

  @override
  List<Object?> get props => [userId, action];
}
