part of 'notifications_badge_bloc.dart';

sealed class NotificationsBadgeEvent extends Equatable {
  const NotificationsBadgeEvent();

  @override
  List<Object?> get props => [];
}

/// Re-reads `GET /notifications/unread-count`.
final class NotificationsBadgeRefreshed extends NotificationsBadgeEvent {
  const NotificationsBadgeRefreshed();
}

/// Drops the count without a request — used on sign-out, since the bloc
/// outlives the session.
final class NotificationsBadgeCleared extends NotificationsBadgeEvent {
  const NotificationsBadgeCleared();
}
