import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// The notification feed: paging, the unread-only filter, and marking read.
///
/// Marking read is optimistic — the row flips locally first — and the tab badge
/// is told to refresh afterwards so the two never disagree for long.
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required this._repository, required this._badge})
    : super(const NotificationsState()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationsRefreshed>(_onRefreshed);
    on<NotificationsNextPageRequested>(_onNextPageRequested);
    on<NotificationsFilterToggled>(_onFilterToggled);
    on<NotificationReadRequested>(_onReadRequested);
    on<NotificationsAllReadRequested>(_onAllReadRequested);
    on<NotificationsCleared>((event, emit) => emit(const NotificationsState()));
  }

  final NotificationRepository _repository;
  final NotificationsBadgeBloc _badge;

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.status == NotificationsStatus.ready) return;

    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    NotificationsRefreshed event,
    Emitter<NotificationsState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _onFilterToggled(
    NotificationsFilterToggled event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(unreadOnly: event.unreadOnly));

    await _loadFirstPage(emit);
  }

  Future<void> _onNextPageRequested(
    NotificationsNextPageRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (!state.hasNext ||
        state.isLoadingMore ||
        state.status != NotificationsStatus.ready) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, clearError: true));

    try {
      final page = await _repository.feed(
        unreadOnly: state.unreadOnly,
        page: state.page + 1,
      );

      emit(
        state.copyWith(
          notifications: [...state.notifications, ...page.items],
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(isLoadingMore: false, errorMessage: exception.message),
      );
    }
  }

  Future<void> _onReadRequested(
    NotificationReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final target = state.notifications
        .where((notification) => notification.id == event.notificationId)
        .firstOrNull;

    if (target == null || target.read) return;

    // Optimistic: the tile must not wait on the network to stop looking unread.
    emit(
      state.copyWith(
        notifications: state.unreadOnly
            ? state.notifications
                  .where(
                    (notification) => notification.id != event.notificationId,
                  )
                  .toList()
            : [
                for (final notification in state.notifications)
                  notification.id == event.notificationId
                      ? notification.asRead()
                      : notification,
              ],
      ),
    );

    try {
      await _repository.markRead(event.notificationId);
      _badge.add(const NotificationsBadgeRefreshed());
    } on ApiException catch (exception) {
      emit(state.copyWith(errorMessage: exception.message));
    }
  }

  Future<void> _onAllReadRequested(
    NotificationsAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _repository.markAllRead();
      _badge.add(const NotificationsBadgeRefreshed());

      await _loadFirstPage(emit);
    } on ApiException catch (exception) {
      emit(state.copyWith(errorMessage: exception.message));
    }
  }

  Future<void> _loadFirstPage(Emitter<NotificationsState> emit) async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));

    try {
      final page = await _repository.feed(unreadOnly: state.unreadOnly);

      emit(
        state.copyWith(
          status: NotificationsStatus.ready,
          notifications: page.items,
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
      _badge.add(const NotificationsBadgeRefreshed());
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          notifications: const [],
          hasNext: false,
          isLoadingMore: false,
          errorMessage: exception.message,
        ),
      );
    }
  }
}
