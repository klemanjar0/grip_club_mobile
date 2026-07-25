import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/view/widgets/lobby_feed_view.dart';

/// Everything you created or were approved to join — past events included, so
/// this doubles as a history.
class MyLobbiesPage extends StatelessWidget {
  const MyLobbiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `.value`: session-scoped singleton — see [LobbiesPage].
    return BlocProvider<MyLobbiesBloc>.value(
      value: getIt<MyLobbiesBloc>()..add(const LobbyFeedRequested()),
      child: Scaffold(
        appBar: AppBar(title: const Text('My lobbies')),
        body: SafeArea(
          child: LobbyFeedView<MyLobbiesBloc>(
            emptyTitle: 'Nothing on your calendar',
            emptySubtitle:
                'Lobbies you create or join show up here, past ones included.',
            emptyAction: Builder(
              builder: (context) => FilledButton.tonalIcon(
                onPressed: () => context.pushNamed(Routes.createLobbyName),
                icon: const Icon(Icons.add),
                label: const Text('Create a lobby'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
