part of 'notifications_bloc.dart';

enum NotificationsStatus { initial, loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.page = 0,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.unreadOnly = false,
    this.errorMessage,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;
  final bool unreadOnly;
  final String? errorMessage;

  bool get isEmpty =>
      status == NotificationsStatus.ready && notifications.isEmpty;

  bool get hasUnread => notifications.any((notification) => !notification.read);

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
    bool? unreadOnly,
    String? errorMessage,
    bool clearError = false,
  }) => NotificationsState(
    status: status ?? this.status,
    notifications: notifications ?? this.notifications,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    unreadOnly: unreadOnly ?? this.unreadOnly,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    notifications,
    page,
    hasNext,
    isLoadingMore,
    unreadOnly,
    errorMessage,
  ];
}
