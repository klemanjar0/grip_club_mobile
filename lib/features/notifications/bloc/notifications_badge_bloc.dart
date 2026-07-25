import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';

part 'notifications_badge_event.dart';
part 'notifications_badge_state.dart';

/// The unread count behind the Notifications tab badge.
///
/// App-lifetime and deliberately tiny: it holds a number, not a feed. Refreshed
/// when the dashboard mounts, on every tab switch, and after anything marks a
/// notification read. There is no push channel, so this is the polling.
class NotificationsBadgeBloc
    extends Bloc<NotificationsBadgeEvent, NotificationsBadgeState> {
  NotificationsBadgeBloc({required this._repository})
    : super(const NotificationsBadgeState()) {
    on<NotificationsBadgeRefreshed>(_onRefreshed);
    on<NotificationsBadgeCleared>(_onCleared);
  }

  final NotificationRepository _repository;

  Future<void> _onRefreshed(
    NotificationsBadgeRefreshed event,
    Emitter<NotificationsBadgeState> emit,
  ) async {
    try {
      emit(NotificationsBadgeState(unread: await _repository.unreadCount()));
    } on ApiException {
      // A badge is not worth an error state: keep the last known count. A 401
      // is already handled globally by the auth interceptor.
    }
  }

  void _onCleared(
    NotificationsBadgeCleared event,
    Emitter<NotificationsBadgeState> emit,
  ) => emit(const NotificationsBadgeState());
}
