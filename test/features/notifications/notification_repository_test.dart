import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';

import '../../helpers/stub_adapter.dart';

Map<String, dynamic> _notificationJson({
  String id = 'n1',
  String type = 'join_request',
  bool read = false,
  String? lobbyId = 'l1',
  Map<String, dynamic>? actor,
}) => <String, dynamic>{
  'id': id,
  'type': type,
  'read': read,
  'created_at': '2026-08-24T18:30:00Z',
  'lobby': <String, dynamic>{'id': lobbyId, 'name': 'Thursday night climb'},
  'actor': actor ?? <String, dynamic>{'id': 'u1', 'display_name': 'rider'},
};

void main() {
  late StubAdapter adapter;

  NotificationRepository repositoryWith(Map<String, Stub> responses) {
    adapter = StubAdapter(responses);
    return NotificationRepository(dio: dioWith(adapter));
  }

  group('feed', () {
    test('parses the envelope and the nested blocks', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications': Stub(200, <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _notificationJson(),
            _notificationJson(
              id: 'n2',
              type: 'lobby_deleted',
              read: true,
              lobbyId: null,
              actor: <String, dynamic>{},
            ),
          ],
          'page': 0,
          'page_size': 10,
          'has_next': true,
        }),
      });

      final page = await repository.feed();

      expect(page.hasNext, isTrue);
      expect(page.items.first.type, NotificationType.joinRequest);
      expect(page.items.first.actor?.displayName, 'rider');
      expect(page.items.first.read, isFalse);

      final deleted = page.items.last;
      expect(deleted.type, NotificationType.lobbyDeleted);
      // The name survives the lobby's deletion; only the id goes null.
      expect(deleted.lobby?.id, isNull);
      expect(deleted.lobby?.name, 'Thursday night climb');
      expect(deleted.lobby?.isDeleted, isTrue);
    });

    test('sends unread=true only when filtering', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications': Stub(200, <String, dynamic>{'items': <dynamic>[]}),
      });

      await repository.feed();
      await repository.feed(unreadOnly: true, page: 1);

      expect(
        adapter.requests.first.queryParameters.containsKey('unread'),
        isFalse,
      );
      // Only the literal string "true" filters server-side.
      expect(adapter.requests.last.queryParameters['unread'], 'true');
      expect(adapter.requests.last.queryParameters['page'], 1);
    });

    test('degrades an unknown type instead of throwing', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications': Stub(200, <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _notificationJson(type: 'lobby_teleported'),
          ],
        }),
      });

      final page = await repository.feed();

      expect(page.items.single.type, NotificationType.unknown);
    });
  });

  test('unreadCount reads the count', () async {
    final repository = repositoryWith(<String, Stub>{
      '/notifications/unread-count': const Stub(200, <String, dynamic>{
        'unread': 7,
      }),
    });

    expect(await repository.unreadCount(), 7);
  });

  group('markRead', () {
    test('succeeds normally', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications/n1/read': const Stub(204, <String, dynamic>{}),
      });

      await repository.markRead('n1');

      expect(adapter.requests.single.path, '/notifications/n1/read');
    });

    test('treats an already-read 404 as success', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications/n1/read': Stub(
          404,
          errorBody('not_found', 'No such notification.'),
        ),
      });

      // The endpoint is not idempotent server-side: a second call 404s. For the
      // UI "it is read now" is true either way.
      await expectLater(repository.markRead('n1'), completes);
    });

    test('still throws on a real failure', () async {
      final repository = repositoryWith(<String, Stub>{
        '/notifications/n1/read': Stub(
          500,
          errorBody('internal_error', 'Something went wrong.'),
        ),
      });

      await expectLater(
        repository.markRead('n1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });

  test('markAllRead returns how many flipped', () async {
    final repository = repositoryWith(<String, Stub>{
      '/notifications/read-all': const Stub(200, <String, dynamic>{
        'marked': 4,
      }),
    });

    expect(await repository.markAllRead(), 4);
  });
}
