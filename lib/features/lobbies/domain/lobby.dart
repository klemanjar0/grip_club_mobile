import 'package:equatable/equatable.dart';

/// Who may see a lobby in the public browse feed.
enum LobbyVisibility {
  public,
  private;

  static LobbyVisibility fromJson(Object? value) => switch (value) {
    'private' => LobbyVisibility.private,
    _ => LobbyVisibility.public,
  };

  String get asJson => name;
}

/// The caller's relationship to a lobby.
///
/// Unlike `User.locale` and friends, this vocabulary is branched on all over
/// the UI, so it is modelled as an enum rather than a raw string. Unknown
/// values degrade to [outsider] — the least-privileged reading.
enum ViewerRole {
  outsider,
  pending,
  member,
  admin;

  static ViewerRole fromJson(Object? value) => switch (value) {
    'admin' => ViewerRole.admin,
    'member' => ViewerRole.member,
    'pending' => ViewerRole.pending,
    _ => ViewerRole.outsider,
  };
}

/// State of a membership row. `null` on the viewer means no row exists.
enum MembershipStatus {
  pending,
  approved,
  banned;

  static MembershipStatus? fromJson(Object? value) => switch (value) {
    'pending' => MembershipStatus.pending,
    'approved' => MembershipStatus.approved,
    'banned' => MembershipStatus.banned,
    _ => null,
  };
}

/// A lobby as returned by every lobby endpoint (`LobbyResponse`).
///
/// [address] and [chatLink] are withheld by the server from non-members even for
/// public lobbies, so `null` there means "not visible to you", not "not set".
class Lobby extends Equatable {
  const Lobby({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.eventTime,
    required this.visibility,
    required this.approvedCount,
    required this.creator,
    required this.viewer,
    this.description,
    this.address,
    this.chatLink,
    this.createdAt,
    this.updatedAt,
  });

  factory Lobby.fromJson(Map<String, dynamic> json) => Lobby(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    country: json['country'] as String? ?? '',
    city: json['city'] as String? ?? '',
    address: json['address'] as String?,
    eventTime: DateTime.tryParse(json['event_time'] as String? ?? ''),
    visibility: LobbyVisibility.fromJson(json['visibility']),
    approvedCount: json['approved_count'] as int? ?? 0,
    chatLink: json['chat_link'] as String?,
    creator: LobbyCreator.fromJson(json['creator']),
    viewer: LobbyViewer.fromJson(json['viewer']),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
  );

  final String id;
  final String name;
  final String? description;
  final String country;
  final String city;

  /// `null` unless the viewer is an admin or an approved member.
  final String? address;

  /// Nullable only defensively — the server always sends a parseable time.
  final DateTime? eventTime;

  final LobbyVisibility visibility;

  /// Approved members, the creator included.
  final int approvedCount;

  /// `null` unless the viewer is an admin or an approved member.
  final String? chatLink;

  final LobbyCreator creator;
  final LobbyViewer viewer;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPrivate => visibility == LobbyVisibility.private;

  /// True once the event time has passed. `/lobbies` never returns these;
  /// `/me/lobbies` does.
  bool get isPast =>
      eventTime != null && eventTime!.isBefore(DateTime.now().toUtc());

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    country,
    city,
    address,
    eventTime,
    visibility,
    approvedCount,
    chatLink,
    creator,
    viewer,
    createdAt,
    updatedAt,
  ];
}

class LobbyCreator extends Equatable {
  const LobbyCreator({required this.id, required this.displayName});

  factory LobbyCreator.fromJson(Object? json) {
    if (json is! Map) return const LobbyCreator(id: '', displayName: '');

    return LobbyCreator(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
    );
  }

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}

/// The `viewer` block: what *this* caller may do with the lobby.
class LobbyViewer extends Equatable {
  const LobbyViewer({
    required this.role,
    required this.canJoin,
    this.membershipStatus,
  });

  factory LobbyViewer.fromJson(Object? json) {
    if (json is! Map) {
      return const LobbyViewer(role: ViewerRole.outsider, canJoin: false);
    }

    return LobbyViewer(
      role: ViewerRole.fromJson(json['role']),
      membershipStatus: MembershipStatus.fromJson(json['membership_status']),
      canJoin: json['can_join'] as bool? ?? false,
    );
  }

  final ViewerRole role;

  /// `null` when no membership row exists.
  final MembershipStatus? membershipStatus;

  /// Server-computed: `false` for banned users and pending applicants too, so
  /// the UI never has to re-derive it.
  final bool canJoin;

  bool get isAdmin => role == ViewerRole.admin;

  bool get isMember => role == ViewerRole.member;

  bool get isPending => role == ViewerRole.pending;

  bool get isBanned => membershipStatus == MembershipStatus.banned;

  /// Admins and approved members see the address and chat link.
  bool get hasFullAccess => isAdmin || isMember;

  @override
  List<Object?> get props => [role, membershipStatus, canJoin];
}
