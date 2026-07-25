import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_state.dart';
import 'package:grip_club_mobile/features/lobbies/view/widgets/lobby_feed_view.dart';

/// Browse tab: upcoming public lobbies you can join.
///
/// The first load sends no `city` or `within`, which makes the server apply the
/// preferences saved on the profile. The filter bar shows those saved values
/// and only starts sending explicit parameters once the user changes one.
class LobbiesPage extends StatelessWidget {
  const LobbiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `.value`: the bloc is a session-scoped singleton, so this page must not
    // close it when the tab is rebuilt.
    return BlocProvider<LobbiesBloc>.value(
      value: getIt<LobbiesBloc>()..add(const LobbyFeedRequested()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Lobbies')),
        body: SafeArea(
          child: Column(
            children: [
              const _LobbyFilterBar(),
              const Expanded(
                child: LobbyFeedView<LobbiesBloc>(
                  canJoin: true,
                  emptyTitle: 'No lobbies here yet',
                  emptySubtitle:
                      'Try a wider time window or a different city — or create '
                      'the first one yourself.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// City + time window. Seeded from the saved preferences, then owned by the
/// bloc once the user touches it.
class _LobbyFilterBar extends StatefulWidget {
  const _LobbyFilterBar();

  @override
  State<_LobbyFilterBar> createState() => _LobbyFilterBarState();
}

class _LobbyFilterBarState extends State<_LobbyFilterBar> {
  static const Map<String, String> _windows = {
    'day': 'Today',
    'week': 'Week',
    'month': 'Month',
    'all': 'All',
  };

  late final TextEditingController _cityController;
  late String _within;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthBloc>().state.user;
    _cityController = TextEditingController(text: user?.city ?? '');
    _within = _windows.containsKey(user?.timeFilter) ? user!.timeFilter : 'all';
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  /// An empty city is sent as `''` on purpose: that is what overrides a saved
  /// city preference and means "everywhere".
  void _apply() => context.read<LobbiesBloc>().add(
    LobbyFeedFilterChanged(city: _cityController.text.trim(), within: _within),
  );

  @override
  Widget build(BuildContext context) {
    final isBusy = context.select(
      (LobbiesBloc bloc) => bloc.state.status == LobbyFeedStatus.loading,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _cityController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _apply(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Any city',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: isBusy ? null : _apply,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final entry in _windows.entries)
                  ButtonSegment<String>(
                    value: entry.key,
                    label: Text(entry.value),
                  ),
              ],
              selected: <String>{_within},
              onSelectionChanged: (selection) {
                setState(() => _within = selection.first);
                _apply();
              },
            ),
          ),
        ],
      ),
    );
  }
}
