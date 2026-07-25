import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/app/router/routes.dart';
import 'package:grip_club_mobile/core/ui/paginated_list_view.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_bloc.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';
import 'package:grip_club_mobile/features/notifications/view/widgets/notification_tile.dart';

/// The notification feed. Polled, not pushed — pull to refresh.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsBloc>.value(
      value: getIt<NotificationsBloc>()..add(const NotificationsRequested()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  Future<void> _refresh(BuildContext context) async =>
      context.read<NotificationsBloc>().add(const NotificationsRefreshed());

  /// Reading a notification marks it read and, when the lobby still exists,
  /// opens it. A deleted lobby has nowhere to go.
  void _onTap(BuildContext context, AppNotification notification) {
    context.read<NotificationsBloc>().add(
      NotificationReadRequested(notification.id),
    );

    final lobbyId = notification.lobby?.id;
    if (lobbyId == null) return;

    context.pushNamed(
      Routes.lobbyDetailName,
      pathParameters: <String, String>{'lobbyId': lobbyId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            builder: (context, state) => Row(
              children: [
                IconButton(
                  tooltip: state.unreadOnly ? 'Show all' : 'Show unread only',
                  isSelected: state.unreadOnly,
                  icon: const Icon(Icons.filter_alt_outlined),
                  selectedIcon: const Icon(Icons.filter_alt),
                  onPressed: () => context.read<NotificationsBloc>().add(
                    NotificationsFilterToggled(unreadOnly: !state.unreadOnly),
                  ),
                ),
                IconButton(
                  tooltip: 'Mark all read',
                  icon: const Icon(Icons.done_all),
                  onPressed: state.hasUnread
                      ? () => context.read<NotificationsBloc>().add(
                          const NotificationsAllReadRequested(),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<NotificationsBloc, NotificationsState>(
          listenWhen: (previous, current) =>
              current.errorMessage != null &&
              current.notifications.isNotEmpty &&
              previous.errorMessage != current.errorMessage,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!))),
          builder: (context, state) {
            if (state.status == NotificationsStatus.loading &&
                state.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == NotificationsStatus.failure &&
                state.notifications.isEmpty) {
              return RefreshableMessage(
                onRefresh: () => _refresh(context),
                child: ErrorRetryView(
                  message:
                      state.errorMessage ?? 'Could not load notifications.',
                  onRetry: () => _refresh(context),
                ),
              );
            }

            if (state.isEmpty) {
              return RefreshableMessage(
                onRefresh: () => _refresh(context),
                child: EmptyStateView(
                  icon: Icons.notifications_none,
                  title: state.unreadOnly
                      ? 'Nothing unread'
                      : 'No notifications yet',
                  subtitle:
                      'Join requests, approvals and lobby changes land here.',
                ),
              );
            }

            return PaginatedListView(
              itemCount: state.notifications.length,
              isLoadingMore: state.isLoadingMore,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              onRefresh: () => _refresh(context),
              onLoadMore: () => context.read<NotificationsBloc>().add(
                const NotificationsNextPageRequested(),
              ),
              itemBuilder: (context, index) {
                final notification = state.notifications[index];

                return NotificationTile(
                  notification: notification,
                  onTap: () => _onTap(context, notification),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
