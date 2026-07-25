import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_detail_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// One lobby in full, with the join / leave action for the current viewer.
///
/// Admin tools (members, edit, delete, invite) are not here yet.
class LobbyDetailPage extends StatelessWidget {
  const LobbyDetailPage({required this.lobbyId, super.key});

  final String lobbyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LobbyDetailBloc>(
      create: (_) =>
          getIt<LobbyDetailBloc>(param1: lobbyId)
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
  };

  Widget _body(BuildContext context, LobbyDetailState state) {
    final lobby = state.lobby;

    // A reload that fails keeps the lobby already on screen; only a first load
    // has nothing to fall back to.
    if (lobby != null) return _LobbyBody(lobby: lobby);

    if (state.status == LobbyDetailStatus.failure) {
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
          appBar: AppBar(title: Text(lobby?.name ?? 'Lobby')),
          body: SafeArea(child: _body(context, state)),
          bottomNavigationBar: lobby == null
              ? null
              : _LobbyAction(lobby: lobby, isActing: state.isActing),
        );
      },
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventTime = lobby.eventTime;
    final description = lobby.description;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
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
  const _DetailTile({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

/// The one action available to this viewer, pinned to the bottom.
///
/// Admins get nothing to press: they cannot leave their own lobby, and editing
/// and deleting are not built yet.
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
