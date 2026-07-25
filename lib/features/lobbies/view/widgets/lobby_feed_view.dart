import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/core/ui/paginated_list_view.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_state.dart';
import 'package:grip_club_mobile/features/lobbies/view/widgets/lobby_card.dart';

/// The list half of a lobby tab: loading, empty, error and paged states.
///
/// Both feeds share it; only the empty state's wording and the presence of a
/// filter bar differ, and those are passed in.
class LobbyFeedView<B extends LobbyFeedBloc> extends StatelessWidget {
  const LobbyFeedView({
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyAction,
    super.key,
  });

  final String emptyTitle;
  final String emptySubtitle;
  final Widget? emptyAction;

  Future<void> _refresh(BuildContext context) async =>
      context.read<B>().add(const LobbyFeedRefreshed());

  /// Opening a lobby can change the viewer's standing in it (they may join, or
  /// leave), so the feed is refreshed when the detail page pops.
  Future<void> _openLobby(BuildContext context, String lobbyId) async {
    await context.pushNamed(
      Routes.lobbyDetailName,
      pathParameters: <String, String>{'lobbyId': lobbyId},
    );

    if (context.mounted) await _refresh(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, LobbyFeedState>(
      // A failure with lobbies already on screen is a failed *next* page: the
      // list stays put and the message goes to a snackbar instead.
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.lobbies.isNotEmpty &&
          previous.errorMessage != current.errorMessage,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.errorMessage!))),
      builder: (context, state) {
        if (state.status == LobbyFeedStatus.loading && state.lobbies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == LobbyFeedStatus.failure && state.lobbies.isEmpty) {
          return RefreshableMessage(
            onRefresh: () => _refresh(context),
            child: ErrorRetryView(
              message: state.errorMessage ?? 'Could not load lobbies.',
              onRetry: () => _refresh(context),
            ),
          );
        }

        if (state.isEmpty) {
          return RefreshableMessage(
            onRefresh: () => _refresh(context),
            child: EmptyStateView(
              icon: Icons.search_off,
              title: emptyTitle,
              subtitle: emptySubtitle,
              action: emptyAction,
            ),
          );
        }

        return PaginatedListView(
          itemCount: state.lobbies.length,
          isLoadingMore: state.isLoadingMore,
          onRefresh: () => _refresh(context),
          onLoadMore: () =>
              context.read<B>().add(const LobbyFeedNextPageRequested()),
          itemBuilder: (context, index) {
            final lobby = state.lobbies[index];

            return LobbyCard(
              lobby: lobby,
              onTap: () => _openLobby(context, lobby.id),
            );
          },
        );
      },
    );
  }
}
