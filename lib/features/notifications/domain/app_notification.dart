import 'package:equatable/equatable.dart';

/// The seven server-defined notification types.
///
/// [unknown] keeps a future server addition from breaking the feed — such a row
/// still renders, with a generic title.
enum NotificationType {
  joinRequest,
  requestApproved,
  requestRejected,
  membershipRemoved,
  membershipBanned,
  lobbyUpdated,
  lobbyDeleted,
  unknown;

  static NotificationType fromJson(Object? value) => switch (value) {
    'join_request' => NotificationType.joinRequest,
    'request_approved' => NotificationType.requestApproved,
    'request_rejected' => NotificationType.requestRejected,
    'membership_removed' => NotificationType.membershipRemoved,
    'membership_banned' => NotificationType.membershipBanned,
    'lobby_updated' => NotificationType.lobbyUpdated,
    'lobby_deleted' => NotificationType.lobbyDeleted,
    _ => NotificationType.unknown,
  };
}

/// One row of the notification feed (`NotificationResponse`).
///
/// Named `AppNotification` rather than `Notification` to stay clear of
/// Flutter's own `Notification` class.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.read,
    this.createdAt,
    this.lobby,
    this.actor,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        type: NotificationType.fromJson(json['type']),
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        lobby: NotificationLobby.fromJson(json['lobby']),
        actor: NotificationActor.fromJson(json['actor']),
      );

  final String id;
  final NotificationType type;
  final bool read;
  final DateTime? createdAt;

  /// `null` when the notification has no lobby context.
  final NotificationLobby? lobby;

  /// `null` once the actor's account is gone.
  final NotificationActor? actor;

  AppNotification asRead() => AppNotification(
    id: id,
    type: type,
    read: true,
    createdAt: createdAt,
    lobby: lobby,
    actor: actor,
  );

  @override
  List<Object?> get props => [id, type, read, createdAt, lobby, actor];
}

/// The lobby a notification is about.
///
/// [name] is snapshotted server-side at write time, so a `lobby_deleted`
/// notification still names the lobby even though [id] has gone `null`.
class NotificationLobby extends Equatable {
  const NotificationLobby({required this.name, this.id});

  static NotificationLobby? fromJson(Object? json) {
    if (json is! Map) return null;

    return NotificationLobby(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
    );
  }

  /// `null` once the lobby has been deleted — nothing left to open.
  final String? id;

  final String name;

  bool get isDeleted => id == null;

  @override
  List<Object?> get props => [id, name];
}

class NotificationActor extends Equatable {
  const NotificationActor({required this.id, required this.displayName});

  static NotificationActor? fromJson(Object? json) {
    if (json is! Map) return null;

    return NotificationActor(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
    );
  }

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}
