import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// One row of a lobby's roster, as `GET /lobbies/{id}/members` returns it.
///
/// Distinct from [Membership], which is what the write endpoints answer with:
/// that one identifies the row by ids, this one carries the person, because the
/// admin reading a roster needs a name to recognise and an email to tell two
/// people with the same one apart.
class LobbyMember extends Equatable {
  const LobbyMember({required this.user, required this.status, this.joinedAt});

  factory LobbyMember.fromJson(Object? json) {
    if (json is! Map) {
      return const LobbyMember(
        user: MemberUser(id: '', displayName: '', email: ''),
        status: MembershipStatus.pending,
      );
    }

    return LobbyMember(
      user: MemberUser.fromJson(json['user']),
      status:
          MembershipStatus.fromJson(json['status']) ?? MembershipStatus.pending,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? ''),
    );
  }

  /// Reads a `MembersResponse`. Not a page — this endpoint is one of the few
  /// that answers with the whole list, so there is no envelope to unwrap.
  static List<LobbyMember> listFromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];

    return items.map(LobbyMember.fromJson).toList(growable: false);
  }

  final MemberUser user;
  final MembershipStatus status;

  /// When they joined, or when they asked to. `null` only defensively.
  final DateTime? joinedAt;

  bool get isApproved => status == MembershipStatus.approved;

  bool get isPending => status == MembershipStatus.pending;

  bool get isBanned => status == MembershipStatus.banned;

  @override
  List<Object?> get props => [user, status, joinedAt];
}

/// The person behind a roster row. Carries no avatar: the members endpoint does
/// not return one, so the roster shows initials.
class MemberUser extends Equatable {
  const MemberUser({
    required this.id,
    required this.displayName,
    required this.email,
  });

  factory MemberUser.fromJson(Object? json) {
    if (json is! Map) {
      return const MemberUser(id: '', displayName: '', email: '');
    }

    final email = json['email'] as String? ?? '';

    return MemberUser(
      id: json['id'] as String? ?? '',
      // The server falls back to the email local part, but a missing key must
      // not leave a nameless row in the roster.
      displayName: switch (json['display_name']) {
        final String name when name.isNotEmpty => name,
        _ => email,
      },
      email: email,
    );
  }

  final String id;
  final String displayName;
  final String email;

  /// One or two letters for the roster's avatar circle. Falls back to `?` for
  /// a name that starts with something unprintable.
  String get initials {
    final source = displayName.isNotEmpty ? displayName : email;
    final words = source.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0])
        .join();

    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  List<Object?> get props => [id, displayName, email];
}
