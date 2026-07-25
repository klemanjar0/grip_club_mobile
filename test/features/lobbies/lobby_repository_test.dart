import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

import '../../helpers/lobby_fixtures.dart';
import '../../helpers/stub_adapter.dart';

void main() {
  late StubAdapter adapter;

  LobbyRepository repositoryWith(Map<String, Stub> responses) {
    adapter = StubAdapter(responses);
    return LobbyRepository(dio: dioWith(adapter));
  }

  group('browse', () {
    test(
      'omits city and within so the server applies saved defaults',
      () async {
        final repository = repositoryWith(<String, Stub>{
          '/lobbies': Stub(200, lobbyPageJson()),
        });

        await repository.browse();

        final query = adapter.requests.single.queryParameters;
        expect(query.containsKey('city'), isFalse);
        expect(query.containsKey('within'), isFalse);
        expect(query['page'], 0);
        expect(query['page_size'], 10);
      },
    );

    test('sends an empty city to mean everywhere', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies': Stub(200, lobbyPageJson()),
      });

      await repository.browse(city: '', within: 'week', page: 2);

      final query = adapter.requests.single.queryParameters;
      // `?city=` is what overrides a saved city preference — dropping the key
      // would silently re-apply it.
      expect(query['city'], '');
      expect(query['within'], 'week');
      expect(query['page'], 2);
    });

    test('parses the page envelope', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies': Stub(
          200,
          lobbyPageJson(
            items: <Map<String, dynamic>>[
              lobbyJson(name: 'Morning session'),
              lobbyJson(
                id: 'a1b2c3d4-0000-4000-8000-000000000002',
                name: 'Evening session',
                visibility: 'private',
              ),
            ],
            hasNext: true,
          ),
        ),
      });

      final page = await repository.browse();

      expect(page.items, hasLength(2));
      expect(page.items.first.name, 'Morning session');
      expect(page.items.last.isPrivate, isTrue);
      expect(page.hasNext, isTrue);
    });

    test('leaves address and chat link null for an outsider', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies': Stub(200, lobbyPageJson()),
      });

      final lobby = (await repository.browse()).items.single;

      // Withheld by the server even for public lobbies — the detail page keys
      // its "join to see the address" note off exactly this.
      expect(lobby.address, isNull);
      expect(lobby.chatLink, isNull);
      expect(lobby.viewer.hasFullAccess, isFalse);
      expect(lobby.viewer.canJoin, isTrue);
    });
  });

  group('byId', () {
    test('parses a member view with the address and chat link', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies/a1b2c3d4-0000-4000-8000-000000000001': Stub(
          200,
          lobbyJson(
            role: 'member',
            membershipStatus: 'approved',
            canJoin: false,
            address: '12 Khreshchatyk',
            chatLink: 'https://chat.example/abc',
          ),
        ),
      });

      final lobby = await repository.byId(
        'a1b2c3d4-0000-4000-8000-000000000001',
      );

      expect(lobby.address, '12 Khreshchatyk');
      expect(lobby.chatLink, 'https://chat.example/abc');
      expect(lobby.viewer.role, ViewerRole.member);
      expect(lobby.viewer.membershipStatus, MembershipStatus.approved);
      expect(lobby.viewer.canJoin, isFalse);
    });

    test('surfaces not_a_member', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies/nope': Stub(
          403,
          errorBody('not_a_member', 'Join the lobby to see its details.'),
        ),
      });

      await expectLater(
        repository.byId('nope'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'not_a_member')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  group('update', () {
    const path = '/lobbies/a1b2c3d4-0000-4000-8000-000000000001';
    const lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';

    test('sends only the keys it is given', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, lobbyJson(role: 'admin', canJoin: false)),
      });

      await repository.update(lobbyId, name: 'Friday night climb');

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.data, <String, dynamic>{'name': 'Friday night climb'});
    });

    test('an omitted clearable field stays out of the body entirely', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, lobbyJson(role: 'admin', canJoin: false)),
      });

      await repository.update(lobbyId, city: 'Lviv');

      final body = adapter.requests.single.data! as Map<String, dynamic>;
      // Absent means "leave it alone" — sending an explicit null would erase it.
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('address'), isFalse);
      expect(body.containsKey('chat_link'), isFalse);
    });

    test(
      'Optional.clear() sends a present null, which erases the field',
      () async {
        final repository = repositoryWith(<String, Stub>{
          path: Stub(200, lobbyJson(role: 'admin', canJoin: false)),
        });

        await repository.update(
          lobbyId,
          description: const Optional<String>.clear(),
          address: const Optional('12 Khreshchatyk'),
        );

        final body = adapter.requests.single.data! as Map<String, dynamic>;
        // The key must be there *carrying* null: that is what clears it.
        expect(body.containsKey('description'), isTrue);
        expect(body['description'], isNull);
        expect(body['address'], '12 Khreshchatyk');
      },
    );

    test('sends event_time as UTC and visibility as its wire value', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, lobbyJson(role: 'admin', canJoin: false)),
      });

      await repository.update(
        lobbyId,
        eventTime: DateTime.utc(2099, 8, 24, 18, 30),
        visibility: LobbyVisibility.private,
      );

      expect(adapter.requests.single.data, <String, dynamic>{
        'event_time': '2099-08-24T18:30:00.000Z',
        'visibility': 'private',
      });
    });

    test('surfaces admin_only', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(403, errorBody('admin_only', 'Only the admin may edit.')),
      });

      await expectLater(
        repository.update(lobbyId, name: 'Nope'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'admin_only')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  group('create', () {
    test('trims fields, drops blank optionals and sends UTC', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies': Stub(201, lobbyJson(role: 'admin', canJoin: false)),
      });

      final lobby = await repository.create(
        LobbyDraft.fromInput(
          name: '  Thursday night climb  ',
          country: ' Ukraine ',
          city: ' Kyiv ',
          eventTime: DateTime.utc(2099, 8, 24, 18, 30),
          visibility: LobbyVisibility.private,
          description: '   ',
          address: ' 12 Khreshchatyk ',
          chatLink: '',
        ),
      );

      final body = adapter.requests.single.data! as Map<String, dynamic>;
      expect(body['name'], 'Thursday night climb');
      expect(body['country'], 'Ukraine');
      expect(body['city'], 'Kyiv');
      expect(body['address'], '12 Khreshchatyk');
      expect(body['visibility'], 'private');
      expect(body['event_time'], '2099-08-24T18:30:00.000Z');
      // Blank optionals are omitted rather than sent as "".
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('chat_link'), isFalse);

      expect(lobby.viewer.isAdmin, isTrue);
    });

    test('surfaces validation_failed details per field', () async {
      final repository = repositoryWith(<String, Stub>{
        '/lobbies': Stub(
          400,
          errorBody(
            'validation_failed',
            'The request payload is invalid.',
            details: <String, String>{'event_time': 'must be in the future'},
          ),
        ),
      });

      await expectLater(
        repository.create(
          LobbyDraft.fromInput(
            name: 'Climb',
            country: 'Ukraine',
            city: 'Kyiv',
            eventTime: DateTime.utc(2020),
            visibility: LobbyVisibility.public,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            <String, String>{'event_time': 'must be in the future'},
          ),
        ),
      );
    });
  });
}
