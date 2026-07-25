import 'package:flutter/material.dart';

import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';

/// One row of the feed. Unread rows are tinted and bold.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = notification.createdAt;

    return Material(
      color: notification.read
          ? Colors.transparent
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(_icon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatRelative(createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The lobby name is snapshotted server-side, so it still reads correctly for
  /// a lobby that has since been deleted.
  String get _lobbyName => notification.lobby?.name ?? 'a lobby';

  String get _actorName => notification.actor?.displayName ?? 'Someone';

  String get _title => switch (notification.type) {
    NotificationType.joinRequest => '$_actorName asked to join $_lobbyName',
    NotificationType.requestApproved => 'You are in — $_lobbyName approved you',
    NotificationType.requestRejected =>
      'Your request to join $_lobbyName was declined',
    NotificationType.membershipRemoved =>
      'You were removed from $_lobbyName — you can rejoin',
    NotificationType.membershipBanned => 'You were banned from $_lobbyName',
    NotificationType.lobbyUpdated => '$_lobbyName was updated',
    NotificationType.lobbyDeleted => '$_lobbyName was cancelled',
    NotificationType.unknown => 'Something happened in $_lobbyName',
  };

  IconData get _icon => switch (notification.type) {
    NotificationType.joinRequest => Icons.person_add_alt,
    NotificationType.requestApproved => Icons.check_circle_outline,
    NotificationType.requestRejected => Icons.cancel_outlined,
    NotificationType.membershipRemoved => Icons.person_remove_alt_1_outlined,
    NotificationType.membershipBanned => Icons.block,
    NotificationType.lobbyUpdated => Icons.edit_calendar_outlined,
    NotificationType.lobbyDeleted => Icons.event_busy,
    NotificationType.unknown => Icons.notifications_outlined,
  };
}
