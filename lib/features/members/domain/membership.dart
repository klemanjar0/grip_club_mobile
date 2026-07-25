import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// A membership row (`MembershipResponse`), returned by join and the admin
/// actions.
///
/// Joining a public lobby yields [MembershipStatus.approved] and a private one
/// yields [MembershipStatus.pending] — both under a `200`, so [status] is the
/// only way to tell which happened.
class Membership extends Equatable {
  const Membership({
    required this.lobbyId,
    required this.userId,
    required this.status,
    this.joinedAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    lobbyId: json['lobby_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    status:
        MembershipStatus.fromJson(json['status']) ?? MembershipStatus.pending,
    joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? ''),
  );

  final String lobbyId;
  final String userId;
  final MembershipStatus status;
  final DateTime? joinedAt;

  bool get isApproved => status == MembershipStatus.approved;

  @override
  List<Object?> get props => [lobbyId, userId, status, joinedAt];
}
