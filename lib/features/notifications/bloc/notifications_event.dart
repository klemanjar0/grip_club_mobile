part of 'notifications_bloc.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

/// First load; a feed that is already on screen is left alone.
final class NotificationsRequested extends NotificationsEvent {
  const NotificationsRequested();
}

final class NotificationsRefreshed extends NotificationsEvent {
  const NotificationsRefreshed();
}

final class NotificationsNextPageRequested extends NotificationsEvent {
  const NotificationsNextPageRequested();
}

final class NotificationsFilterToggled extends NotificationsEvent {
  const NotificationsFilterToggled({required this.unreadOnly});

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}

final class NotificationReadRequested extends NotificationsEvent {
  const NotificationReadRequested(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

final class NotificationsAllReadRequested extends NotificationsEvent {
  const NotificationsAllReadRequested();
}

/// Drops the loaded feed on sign-out — this bloc outlives a session.
final class NotificationsCleared extends NotificationsEvent {
  const NotificationsCleared();
}
