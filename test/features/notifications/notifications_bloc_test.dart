import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_bloc.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

AppNotification _notification({required String id, bool read = false}) =>
    AppNotification(
      id: id,
      type: NotificationType.joinRequest,
      read: read,
      createdAt: DateTime.utc(2026, 8, 24, 18, 30),
      lobby: const NotificationLobby(id: 'l1', name: 'Thursday night climb'),
    );

PageEnvelope<AppNotification> _page(
  List<AppNotification> items, {
  bool hasNext = false,
}) => PageEnvelope<AppNotification>(
  items: items,
  page: 0,
  pageSize: 10,
  hasNext: hasNext,
);

void main() {
  late NotificationRepository repository;
  late NotificationsBadgeBloc badge;

  setUp(() {
    repository = _MockNotificationRepository();
    badge = NotificationsBadgeBloc(repository: repository);
    when(repository.unreadCount).thenAnswer((_) async => 0);
  });

  tearDown(() async => badge.close());

  NotificationsBloc build() =>
      NotificationsBloc(repository: repository, badge: badge);

  blocTest<NotificationsBloc, NotificationsState>(
    'loads the first page and refreshes the badge',
    setUp: () => when(
      () => repository.feed(
        unreadOnly: any(named: 'unreadOnly'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => _page([_notification(id: 'n1')])),
    build: build,
    act: (bloc) => bloc.add(const NotificationsRequested()),
    expect: () => [
      const NotificationsState(status: NotificationsStatus.loading),
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [_notification(id: 'n1')],
      ),
    ],
    verify: (_) => verify(repository.unreadCount).called(1),
  );

  blocTest<NotificationsBloc, NotificationsState>(
    'marks a notification read optimistically',
    setUp: () {
      when(() => repository.markRead('n1')).thenAnswer((_) async {});
    },
    build: build,
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      notifications: [
        _notification(id: 'n1'),
        _notification(id: 'n2'),
      ],
    ),
    act: (bloc) => bloc.add(const NotificationReadRequested('n1')),
    expect: () => [
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [
          _notification(id: 'n1', read: true),
          _notification(id: 'n2'),
        ],
      ),
    ],
    verify: (_) => verify(() => repository.markRead('n1')).called(1),
  );

  blocTest<NotificationsBloc, NotificationsState>(
    'drops a row from the unread-only list once it is read',
    setUp: () => when(() => repository.markRead('n1')).thenAnswer((_) async {}),
    build: build,
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      unreadOnly: true,
      notifications: [
        _notification(id: 'n1'),
        _notification(id: 'n2'),
      ],
    ),
    act: (bloc) => bloc.add(const NotificationReadRequested('n1')),
    expect: () => [
      NotificationsState(
        status: NotificationsStatus.ready,
        unreadOnly: true,
        notifications: [_notification(id: 'n2')],
      ),
    ],
  );

  blocTest<NotificationsBloc, NotificationsState>(
    'ignores a row that is already read',
    build: build,
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      notifications: [_notification(id: 'n1', read: true)],
    ),
    act: (bloc) => bloc.add(const NotificationReadRequested('n1')),
    expect: () => <NotificationsState>[],
    verify: (_) => verifyNever(() => repository.markRead(any())),
  );

  blocTest<NotificationsBloc, NotificationsState>(
    'clearing empties the feed for the next session',
    build: build,
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      notifications: [_notification(id: 'n1')],
    ),
    act: (bloc) => bloc.add(const NotificationsCleared()),
    expect: () => const [NotificationsState()],
  );

  group('NotificationsBadgeBloc', () {
    blocTest<NotificationsBadgeBloc, NotificationsBadgeState>(
      'reads the unread count',
      setUp: () => when(repository.unreadCount).thenAnswer((_) async => 3),
      build: () => NotificationsBadgeBloc(repository: repository),
      act: (bloc) => bloc.add(const NotificationsBadgeRefreshed()),
      expect: () => const [NotificationsBadgeState(unread: 3)],
    );

    blocTest<NotificationsBadgeBloc, NotificationsBadgeState>(
      'keeps the last count when the request fails',
      setUp: () => when(repository.unreadCount).thenThrow(Exception('boom')),
      build: () => NotificationsBadgeBloc(repository: repository),
      seed: () => const NotificationsBadgeState(unread: 2),
      act: (bloc) => bloc.add(const NotificationsBadgeRefreshed()),
      errors: () => [isA<Exception>()],
    );
  });

  test('the badge label caps at 99+', () {
    expect(const NotificationsBadgeState(unread: 5).label, '5');
    expect(const NotificationsBadgeState(unread: 120).label, '99+');
    expect(const NotificationsBadgeState().hasUnread, isFalse);
  });
}
