import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';

/// The signed-in shell: four tabs around a centre "create lobby" button.
///
/// The `+` is a bar destination rather than a floating action button because it
/// belongs to the whole dashboard, not to any one tab. It never becomes the
/// selected destination — tapping it pushes the create form over the shell and
/// leaves the current tab where it was.
class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Index of the `+` in the bar. Branch indices sit either side of it, which
  /// is what [_toBranch] and [_toDestination] convert between.
  static const int _createIndex = 2;

  @override
  void initState() {
    super.initState();
    _refreshBadge();
  }

  /// Bar index → branch index: 0,1 pass through; 3,4 shift down past the `+`.
  int _toBranch(int destinationIndex) =>
      destinationIndex > _createIndex ? destinationIndex - 1 : destinationIndex;

  /// Branch index → bar index.
  int _toDestination(int branchIndex) =>
      branchIndex >= _createIndex ? branchIndex + 1 : branchIndex;

  void _refreshBadge() =>
      getIt<NotificationsBadgeBloc>().add(const NotificationsBadgeRefreshed());

  void _onDestinationSelected(int index) {
    if (index == _createIndex) {
      context.pushNamed(Routes.createLobbyName);
      return;
    }

    final branch = _toBranch(index);

    widget.navigationShell.goBranch(
      branch,
      // Re-tapping the active tab pops that branch back to its root.
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
    _refreshBadge();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _toDestination(widget.navigationShell.currentIndex),
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Lobbies',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'My lobbies',
          ),
          NavigationDestination(
            icon: _CreateLobbyIcon(color: theme.colorScheme.primary),
            label: 'Create',
            tooltip: 'Create a lobby',
          ),
          NavigationDestination(
            icon: const _NotificationsIcon(),
            selectedIcon: const _NotificationsIcon(selected: true),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CreateLobbyIcon extends StatelessWidget {
  const _CreateLobbyIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.add,
        size: 22,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

/// Bell with the unread count on it. Reads the app-lifetime badge bloc directly
/// so no tab has to own the count.
class _NotificationsIcon extends StatelessWidget {
  const _NotificationsIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_outlined,
    );

    return BlocBuilder<NotificationsBadgeBloc, NotificationsBadgeState>(
      bloc: getIt<NotificationsBadgeBloc>(),
      builder: (context, state) =>
          state.hasUnread ? Badge(label: Text(state.label), child: icon) : icon,
    );
  }
}
