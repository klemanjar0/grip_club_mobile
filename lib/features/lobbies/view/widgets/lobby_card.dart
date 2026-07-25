import 'package:flutter/material.dart';

import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// One lobby in a feed. Shared by the browse and My Lobbies tabs.
class LobbyCard extends StatelessWidget {
  const LobbyCard({
    required this.lobby,
    required this.onTap,
    this.onJoin,
    this.isJoining = false,
    super.key,
  });

  final Lobby lobby;
  final VoidCallback onTap;

  /// Supplied by the browse feed only. My Lobbies leaves it null — every lobby
  /// there is already the caller's.
  final VoidCallback? onJoin;

  /// This card's join is in flight.
  final bool isJoining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventTime = lobby.eventTime;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lobby.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (lobby.isPrivate) ...[
                    const SizedBox(height: 8),
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _IconLine(
                icon: Icons.schedule,
                text: eventTime == null
                    ? 'Time to be announced'
                    : formatEventTime(eventTime),
                emphasised: lobby.isPast,
              ),
              const SizedBox(height: 4),
              _IconLine(
                icon: Icons.place_outlined,
                text: '${lobby.city}, ${lobby.country}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${lobby.approvedCount} going',
                    style: theme.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  ...?_roleChip(context),
                ],
              ),
              ...?_joinButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Join straight from the list, without opening the lobby first.
  ///
  /// A public lobby lets you in on the spot; a private one only sends the
  /// organizer a request, and the label says so rather than promising entry.
  /// Absent for anyone the server says cannot join — members, admins, pending
  /// applicants and banned users all have `can_join: false`.
  List<Widget>? _joinButton(BuildContext context) {
    if (onJoin == null || !lobby.viewer.canJoin) return null;

    return [
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: isJoining ? null : onJoin,
          child: isJoining
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(lobby.isPrivate ? 'Request to join' : 'Join'),
        ),
      ),
    ];
  }

  /// Only shown once the viewer has some standing in the lobby — an outsider
  /// browsing the feed would see the same empty chip on every card.
  List<Widget>? _roleChip(BuildContext context) {
    final (String label, Color? color) = switch (lobby.viewer.role) {
      ViewerRole.admin => ('Admin', Theme.of(context).colorScheme.primary),
      ViewerRole.member => ('Member', null),
      ViewerRole.pending => ('Pending', Theme.of(context).colorScheme.tertiary),
      ViewerRole.outsider => ('', null),
    };

    if (label.isEmpty) return null;

    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color ?? Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    ];
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    this.emphasised = false,
  });

  final IconData icon;
  final String text;

  /// Dims the line — used for events that have already happened.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasised
        ? theme.colorScheme.outline
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
