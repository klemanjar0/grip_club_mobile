import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/bloc/lobby_members_bloc.dart';
import 'package:grip_club_mobile/features/members/view/widgets/member_tile.dart';

/// The roster of one lobby, for its admin.
///
/// Three lists behind one filter rather than three tabs: the API serves one
/// status at a time, so a filter is what the data actually is — and a swipeable
/// tab view would keep two rosters on screen that have not been read yet.
class LobbyMembersPage extends StatelessWidget {
  const LobbyMembersPage({required this.lobbyId, this.lobbyName, super.key});

  final String lobbyId;

  /// Shown under the title, when the caller had it. Absent on a deep link.
  final String? lobbyName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LobbyMembersBloc>(
      create: (_) =>
          getIt<LobbyMembersBloc>(param1: lobbyId)
            ..add(const LobbyMembersRequested()),
      child: _LobbyMembersView(lobbyName: lobbyName),
    );
  }
}

class _LobbyMembersView extends StatelessWidget {
  const _LobbyMembersView({this.lobbyName});

  final String? lobbyName;

  String _outcomeMessage(LobbyMemberOutcome outcome) {
    final name = outcome.memberName;

    return switch (outcome.action) {
      LobbyMemberAction.approve => '$name is in.',
      LobbyMemberAction.reject => 'Request from $name declined.',
      LobbyMemberAction.ban => '$name is banned.',
      // Reads for both halves of the endpoint without having to know which one
      // ran: the row is gone either way.
      LobbyMemberAction.remove => '$name is no longer on this list.',
    };
  }

  @override
  Widget build(BuildContext context) {
    // Actions against your own id are `403 cannot_target_self`, so the admin's
    // own row shows no menu. The roster carries ids, not roles, which is why
    // this comes from the session rather than from the list.
    final selfId = context.select((AuthBloc bloc) => bloc.state.user?.id);

    return BlocConsumer<LobbyMembersBloc, LobbyMembersState>(
      listenWhen: (previous, current) =>
          previous.outcome != current.outcome ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        final outcome = state.outcome;

        if (outcome != null) {
          // `approved_count` moved, and it is on the card in both feeds. This
          // page sits above the tab shell, so they are out of reach through the
          // tree — the same reason the create and edit forms call this.
          refreshLobbyFeeds();

          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_outcomeMessage(outcome))));
          return;
        }

        // A roster that failed to load renders as a full-page error instead;
        // only a failed *action* needs a snackbar.
        if (state.errorMessage case final message? when state.visible != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final bloc = context.read<LobbyMembersBloc>();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Members'),
                if (lobbyName case final name?)
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _RosterFilter(
                  filter: state.filter,
                  countOf: state.countOf,
                  onChanged: (filter) =>
                      bloc.add(LobbyMembersFilterChanged(filter)),
                ),
                Expanded(
                  child: _Roster(state: state, selfId: selfId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Which roster is on screen. Counts appear as each one is read — guessing them
/// before that would mean showing a number that is wrong.
class _RosterFilter extends StatelessWidget {
  const _RosterFilter({
    required this.filter,
    required this.countOf,
    required this.onChanged,
  });

  static const Map<MembershipStatus, String> labels = {
    MembershipStatus.approved: 'Members',
    MembershipStatus.pending: 'Requests',
    MembershipStatus.banned: 'Banned',
  };

  final MembershipStatus filter;
  final int? Function(MembershipStatus) countOf;
  final ValueChanged<MembershipStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SegmentedButton<MembershipStatus>(
        showSelectedIcon: false,
        segments: [
          for (final entry in labels.entries)
            ButtonSegment<MembershipStatus>(
              value: entry.key,
              label: Text(switch (countOf(entry.key)) {
                final int count => '${entry.value} $count',
                _ => entry.value,
              }),
            ),
        ],
        selected: <MembershipStatus>{filter},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.state, required this.selfId});

  final LobbyMembersState state;
  final String? selfId;

  @override
  Widget build(BuildContext context) {
    final members = state.visible;

    // Nothing to fall back on yet.
    if (members == null) {
      if (state.isLoadingFirstTime) {
        return const Center(child: CircularProgressIndicator());
      }

      return ErrorRetryView(
        message: state.errorMessage ?? 'Could not load this roster.',
        onRetry: () =>
            context.read<LobbyMembersBloc>().add(const LobbyMembersRefreshed()),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<LobbyMembersBloc>().add(const LobbyMembersRefreshed()),
      child: members.isEmpty
          // Inside a scrollable so pull-to-refresh still works when the list
          // is empty — the same trick the feeds use.
          ? ListView(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: _EmptyRoster(filter: state.filter),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];

                return MemberTile(
                  member: member,
                  isSelf: member.user.id == selfId,
                  isBusy: state.isBusy(member.user.id),
                  onAction: (action) => context.read<LobbyMembersBloc>().add(
                    LobbyMemberActionRequested(
                      userId: member.user.id,
                      action: action,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster({required this.filter});

  final MembershipStatus filter;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      MembershipStatus.approved => const EmptyStateView(
        icon: Icons.group_outlined,
        title: 'Nobody has joined yet',
        subtitle: 'Share the invite link and they will show up here.',
      ),
      MembershipStatus.pending => const EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'No requests waiting',
        subtitle: 'People asking to join a private lobby appear here.',
      ),
      MembershipStatus.banned => const EmptyStateView(
        icon: Icons.block,
        title: 'Nobody is banned',
        subtitle:
            'A ban is permanent for the person — this list stays empty '
            'unless you need it.',
      ),
    };
  }
}
