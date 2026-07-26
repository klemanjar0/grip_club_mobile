import 'package:flutter/material.dart';

import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/bloc/lobby_members_bloc.dart';
import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';

/// One person on the roster, with whatever the admin may do to them.
///
/// The actions on offer come from the row's own status — see
/// [LobbyMemberAction.forStatus] — so a tile never has to know which roster it
/// is sitting in.
class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.member,
    required this.onAction,
    this.isSelf = false,
    this.isBusy = false,
    super.key,
  });

  final LobbyMember member;

  /// Runs once the admin has confirmed, where confirmation is called for.
  final ValueChanged<LobbyMemberAction> onAction;

  /// This row is the admin themselves. The API answers `403 cannot_target_self`
  /// to every action against your own id, so the menu is not offered at all
  /// rather than offered and refused.
  final bool isSelf;

  /// An action against this row is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinedAt = member.joinedAt;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: member.isBanned
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        foregroundColor: member.isBanned
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSecondaryContainer,
        child: Text(member.user.initials, style: theme.textTheme.labelLarge),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 8),
            _Badge(label: 'You', color: theme.colorScheme.primary),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (joinedAt != null)
            Text(
              switch (member.status) {
                MembershipStatus.pending => 'Asked ${formatRelative(joinedAt)}',
                MembershipStatus.banned => 'Banned ${formatRelative(joinedAt)}',
                MembershipStatus.approved =>
                  'Joined ${formatRelative(joinedAt)}',
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      isThreeLine: joinedAt != null,
      trailing: _trailing(context),
    );
  }

  Widget? _trailing(BuildContext context) {
    if (isBusy) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // The organizer's own row: nothing on offer, and the reason is worth
    // saying — "no menu" on its own reads as a bug.
    if (isSelf) {
      return Text(
        'Organizer',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final actions = LobbyMemberAction.forStatus(member.status);
    if (actions.isEmpty) return null;

    return PopupMenuButton<LobbyMemberAction>(
      tooltip: 'Manage ${member.user.displayName}',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _confirmThenRun(context, action),
      itemBuilder: (menuContext) => [
        for (final action in actions)
          PopupMenuItem<LobbyMemberAction>(
            value: action,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                action.iconFor(member.status),
                color: action.isDestructiveFor(member.status)
                    ? Theme.of(menuContext).colorScheme.error
                    : null,
              ),
              title: Text(
                action.labelFor(member.status),
                style: action.isDestructiveFor(member.status)
                    ? TextStyle(color: Theme.of(menuContext).colorScheme.error)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  /// Everything that cannot be taken back — or that sends a notification the
  /// person will read — is confirmed first. Approving and declining are not:
  /// both are ordinary, and a decline can simply be asked again.
  Future<void> _confirmThenRun(
    BuildContext context,
    LobbyMemberAction action,
  ) async {
    final prompt = action.promptFor(member.user.displayName, member.status);
    if (prompt == null) {
      onAction(action);
      return;
    }

    final colors = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(prompt.title),
        content: Text(prompt.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: action.isDestructiveFor(member.status)
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(prompt.confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed ?? false) onAction(action);
  }
}

/// What a confirmation dialog says, for the actions that need one.
class ActionPrompt {
  const ActionPrompt({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;
}

/// How each action is put to the admin.
///
/// Everything here takes the row's own status, because one endpoint means two
/// different things depending on where it is used: deleting the membership row
/// of an approved member removes them, and deleting the row of a banned one is
/// the only way a ban is ever lifted. Calling both "Remove from lobby" would
/// hide the more consequential half.
extension LobbyMemberActionUi on LobbyMemberAction {
  String labelFor(MembershipStatus status) => switch ((this, status)) {
    (LobbyMemberAction.approve, _) => 'Approve',
    (LobbyMemberAction.reject, _) => 'Decline',
    (LobbyMemberAction.ban, _) => 'Ban from lobby',
    (LobbyMemberAction.remove, MembershipStatus.banned) => 'Lift ban',
    (LobbyMemberAction.remove, _) => 'Remove from lobby',
  };

  IconData iconFor(MembershipStatus status) => switch ((this, status)) {
    (LobbyMemberAction.approve, _) => Icons.check_circle_outline,
    (LobbyMemberAction.reject, _) => Icons.cancel_outlined,
    (LobbyMemberAction.ban, _) => Icons.block,
    (LobbyMemberAction.remove, MembershipStatus.banned) => Icons.lock_open,
    (LobbyMemberAction.remove, _) => Icons.person_remove_outlined,
  };

  /// Lifting a ban gives access back, so it is not styled as a loss.
  bool isDestructiveFor(MembershipStatus status) => switch ((this, status)) {
    (LobbyMemberAction.ban, _) => true,
    (LobbyMemberAction.remove, MembershipStatus.banned) => false,
    (LobbyMemberAction.remove, _) => true,
    _ => false,
  };

  /// `null` for the actions that go straight through.
  ActionPrompt? promptFor(String name, MembershipStatus status) =>
      switch ((this, status)) {
        // Both are ordinary verdicts on a request, and neither is final.
        (LobbyMemberAction.approve, _) || (LobbyMemberAction.reject, _) => null,
        (LobbyMemberAction.ban, _) => ActionPrompt(
          title: 'Ban $name?',
          body:
              'They lose access and cannot join again — a ban is the one thing '
              'here that cannot be undone from their side. They are notified.',
          confirmLabel: 'Ban',
        ),
        (LobbyMemberAction.remove, MembershipStatus.banned) => ActionPrompt(
          title: 'Lift the ban on $name?',
          body:
              'The ban is removed and they may join this lobby again. They are '
              'notified.',
          confirmLabel: 'Lift ban',
        ),
        (LobbyMemberAction.remove, _) => ActionPrompt(
          title: 'Remove $name?',
          body:
              'They lose access to the address and the group chat, and are '
              'notified. They may join again afterwards.',
          confirmLabel: 'Remove',
        ),
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
