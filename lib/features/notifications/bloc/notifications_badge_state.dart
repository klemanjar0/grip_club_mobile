part of 'notifications_badge_bloc.dart';

class NotificationsBadgeState extends Equatable {
  const NotificationsBadgeState({this.unread = 0});

  final int unread;

  bool get hasUnread => unread > 0;

  /// Badges stop being readable past three digits.
  String get label => unread > 99 ? '99+' : '$unread';

  @override
  List<Object?> get props => [unread];
}
