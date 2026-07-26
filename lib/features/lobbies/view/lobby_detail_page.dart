import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/core/ui/avatar_image.dart';
import 'package:grip_club_mobile/core/ui/avatar_viewer.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_detail_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// One lobby in full, with the join / leave action for the current viewer.
///
/// An admin gets edit and delete in the app bar, and the roster from the body.
/// Sharing the invite link is not here yet.
class LobbyDetailPage extends StatelessWidget {
  const LobbyDetailPage({required this.lobbyId, this.initialLobby, super.key});

  final String lobbyId;

  /// The copy the feed already had, when the page was opened from a list.
  /// Absent on a deep link or a notification tap.
  final Lobby? initialLobby;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LobbyDetailBloc>(
      create: (_) =>
          getIt<LobbyDetailBloc>(param1: lobbyId, param2: initialLobby)
            ..add(const LobbyDetailRequested()),
      child: const _LobbyDetailView(),
    );
  }
}

class _LobbyDetailView extends StatelessWidget {
  const _LobbyDetailView();

  String _outcomeMessage(LobbyDetailOutcome outcome) => switch (outcome) {
    LobbyDetailOutcome.joined => 'You are in.',
    LobbyDetailOutcome.requestSent =>
      'Request sent — the organizer will review it.',
    LobbyDetailOutcome.left => 'You left the lobby.',
    LobbyDetailOutcome.requestWithdrawn => 'Request withdrawn.',
    LobbyDetailOutcome.deleted => 'Lobby deleted.',
  };

  /// Opens the edit form and takes the saved lobby back from it. `PATCH`
  /// answers with the updated lobby in full, so nothing needs re-reading.
  Future<void> _edit(BuildContext context, Lobby lobby) async {
    final bloc = context.read<LobbyDetailBloc>();

    final saved = await context.pushNamed<Lobby>(
      Routes.editLobbyName,
      pathParameters: <String, String>{'lobbyId': lobby.id},
      extra: lobby,
    );

    if (saved != null) bloc.add(LobbyDetailUpdated(saved));
  }

  /// Asks before deleting: it cannot be undone, and everyone who joined is
  /// notified and loses the lobby.
  Future<void> _confirmDelete(BuildContext context, Lobby lobby) async {
    final bloc = context.read<LobbyDetailBloc>();
    final colors = Theme.of(context).colorScheme;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this lobby?'),
        content: Text(
          // `approved_count` includes the admin, so anything above one means
          // other people are affected.
          lobby.approvedCount > 1
              ? 'Everyone who joined is notified and loses access. This cannot '
                    'be undone.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep lobby'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) bloc.add(const LobbyDetailDeleteRequested());
  }

  Widget _body(BuildContext context, LobbyDetailState state) {
    final lobby = state.lobby;

    // A reload that fails keeps the lobby already on screen; only a first load
    // has nothing to fall back to.
    if (lobby != null) return _LobbyBody(lobby: lobby);

    if (state.status == LobbyDetailStatus.failure) {
      // Not a broken request — the lobby exists and is simply closed until the
      // caller joins it. Offering "Retry" would just fail again; offering the
      // join is the way through. Whether it lets them straight in or only sends
      // a request is the server's call, and unknowable from here: the details
      // that would say which are exactly what is being withheld.
      if (state.isRestricted) {
        return _RestrictedView(
          isActing: state.isActing,
          hasPendingRequest: state.outcome == LobbyDetailOutcome.requestSent,
        );
      }

      return ErrorRetryView(
        message: state.errorMessage ?? 'Could not load this lobby.',
        onRetry: () =>
            context.read<LobbyDetailBloc>().add(const LobbyDetailRequested()),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyDetailBloc, LobbyDetailState>(
      listenWhen: (previous, current) =>
          previous.outcome != current.outcome ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        final outcome = state.outcome;
        final error = state.errorMessage;

        if (outcome != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_outcomeMessage(outcome))));

          // The lobby is gone: there is no page left to stand on, and it has to
          // come out of both feeds. This page is pushed above the tab shell, so
          // the feeds are out of reach through the tree.
          if (outcome == LobbyDetailOutcome.deleted) {
            refreshLobbyFeeds();
            context.pop();
            return;
          }

          // Leaving a private lobby costs the viewer the right to read it, so
          // there is nothing left to show.
          if (state.accessLost) context.pop();
          return;
        }

        // A failed *load* renders as a full-page error instead.
        if (error != null && state.status != LobbyDetailStatus.failure) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
        }
      },
      builder: (context, state) {
        final lobby = state.lobby;

        return Scaffold(
          appBar: AppBar(
            title: Text(lobby?.name ?? 'Lobby'),
            actions: [
              // The admin's tools. Managing the roster lives in the body, next
              // to the count it changes. Both of these are held shut while an
              // action is in flight: a delete takes the lobby out from under
              // the edit form.
              if (lobby != null && lobby.viewer.isAdmin) ...[
                IconButton(
                  tooltip: 'Edit lobby',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: state.isActing
                      ? null
                      : () => _edit(context, lobby),
                ),
                IconButton(
                  tooltip: 'Delete lobby',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.isActing
                      ? null
                      : () => _confirmDelete(context, lobby),
                ),
              ],
            ],
          ),
          body: SafeArea(child: _body(context, state)),
          bottomNavigationBar: lobby == null
              ? null
              : _LobbyAction(lobby: lobby, isActing: state.isActing),
        );
      },
    );
  }
}

/// Shown when the lobby is real but closed to the caller and the feed's copy
/// was not carried in — a deep link, or a tap on a notification.
///
/// There is nothing to describe, so the page offers the one thing that changes
/// the situation.
class _RestrictedView extends StatelessWidget {
  const _RestrictedView({
    required this.isActing,
    required this.hasPendingRequest,
  });

  final bool isActing;

  /// The join turned out to be a request, and it is still waiting. The lobby
  /// stays closed until the organizer answers.
  final bool hasPendingRequest;

  @override
  Widget build(BuildContext context) {
    if (hasPendingRequest) {
      return const EmptyStateView(
        icon: Icons.hourglass_empty,
        title: 'Request sent',
        subtitle:
            'The organizer will review it. The lobby opens up once you are '
            'approved.',
      );
    }

    return EmptyStateView(
      icon: Icons.lock_outline,
      title: 'Members only',
      subtitle:
          'Join to see the schedule, the exact address and the group chat. '
          'A private lobby will ask its organizer first.',
      action: FilledButton(
        onPressed: isActing
            ? null
            : () => context.read<LobbyDetailBloc>().add(
                const LobbyDetailJoinRequested(),
              ),
        child: isActing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Join lobby'),
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.lobby});

  final Lobby lobby;

  /// Opens the roster, then re-reads the lobby: approving, banning and removing
  /// all move `approved_count`, which this page shows.
  ///
  /// Re-read unconditionally rather than on a result handed back by the roster.
  /// Returning one would mean intercepting the pop, and a route that intercepts
  /// its own pop loses the iOS swipe-back gesture — a worse trade than one GET
  /// after a look that changed nothing. The feeds are refreshed by the roster
  /// itself, where a change actually lands.
  Future<void> _openMembers(BuildContext context) async {
    final bloc = context.read<LobbyDetailBloc>();

    await context.pushNamed<void>(
      Routes.lobbyMembersName,
      pathParameters: <String, String>{'lobbyId': lobby.id},
      extra: lobby.name,
    );

    bloc.add(const LobbyDetailRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventTime = lobby.eventTime;
    final description = lobby.description;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Only when there is one: an empty placeholder banner would be a large
        // piece of nothing at the top of every lobby without a photo.
        if (lobby.avatar case final avatar?) ...[
          GestureDetector(
            // The banner is cropped to 16:9, so a tap is the only way to see
            // the whole picture.
            onTap: () =>
                showAvatarViewer(context, image: avatar, title: lobby.name),
            child: AvatarImage.banner(
              image: avatar,
              icon: Icons.image_outlined,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Icon(
              lobby.isPrivate ? Icons.lock_outline : Icons.public,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              lobby.isPrivate ? 'Private lobby' : 'Public lobby',
              style: theme.textTheme.labelMedium,
            ),
            const Spacer(),
            Text(
              '${lobby.approvedCount} going',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(lobby.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        _DetailTile(
          icon: Icons.schedule,
          title: eventTime == null
              ? 'Time to be announced'
              : formatEventTime(eventTime),
          subtitle: lobby.isPast ? 'This event has already happened' : null,
        ),
        _DetailTile(
          icon: Icons.place_outlined,
          title: '${lobby.city}, ${lobby.country}',
          subtitle: lobby.address,
        ),
        _DetailTile(
          icon: Icons.person_outline,
          title: lobby.creator.displayName,
          subtitle: 'Organizer',
        ),
        // The way in to the roster. Only the admin may read it — everyone else
        // gets `403 admin_only` — so only the admin is offered it.
        if (lobby.viewer.isAdmin)
          _DetailTile(
            icon: Icons.groups_outlined,
            title: 'Manage members',
            subtitle: lobby.isPrivate
                ? 'Approve requests, remove or ban people'
                : 'Remove or ban people',
            onTap: () => _openMembers(context),
          ),
        if (lobby.chatLink case final chatLink?)
          _DetailTile(
            icon: Icons.chat_bubble_outline,
            title: chatLink,
            subtitle: 'Group chat',
          ),
        if (!lobby.viewer.hasFullAccess)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Join to see the exact address and the group chat link.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (description != null) ...[
          const SizedBox(height: 24),
          Text('About', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Makes the row a control. Everything else here is read-only, so the
  /// chevron is what tells the two apart.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// The one action available to this viewer, pinned to the bottom.
///
/// Admins get nothing to press: they cannot leave their own lobby, and their
/// edit and delete live in the app bar.
class _LobbyAction extends StatelessWidget {
  const _LobbyAction({required this.lobby, required this.isActing});

  final Lobby lobby;
  final bool isActing;

  Future<void> _confirmLeave(BuildContext context) async {
    final bloc = context.read<LobbyDetailBloc>();

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this lobby?'),
        content: Text(
          lobby.isPrivate
              ? 'You will have to ask to join again.'
              : 'You can join again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave ?? false) bloc.add(const LobbyDetailLeaveRequested());
  }

  @override
  Widget build(BuildContext context) {
    final viewer = lobby.viewer;

    final Widget? action = switch (viewer.role) {
      ViewerRole.admin => null,
      ViewerRole.member => OutlinedButton(
        onPressed: isActing ? null : () => _confirmLeave(context),
        child: const Text('Leave lobby'),
      ),
      ViewerRole.pending => OutlinedButton(
        onPressed: isActing ? null : () => _confirmLeave(context),
        child: const Text('Withdraw request'),
      ),
      ViewerRole.outsider when viewer.canJoin => FilledButton(
        onPressed: isActing
            ? null
            : () => context.read<LobbyDetailBloc>().add(
                const LobbyDetailJoinRequested(),
              ),
        child: Text(lobby.isPrivate ? 'Request to join' : 'Join lobby'),
      ),
      // An outsider who cannot join is banned — say so rather than showing a
      // button that is guaranteed to fail.
      ViewerRole.outsider => null,
    };

    final theme = Theme.of(context);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewer.isPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Waiting for the organizer to approve you.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (viewer.isBanned)
            Text(
              'You cannot join this lobby.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (isActing)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          ?action,
        ],
      ),
    );
  }
}
