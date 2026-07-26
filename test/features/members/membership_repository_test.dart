import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';

import '../../helpers/member_fixtures.dart';
import '../../helpers/stub_adapter.dart';

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';
const _userId = 'u0000000-0000-4000-8000-000000000001';

Map<String, dynamic> _membershipJson({String status = 'approved'}) =>
    <String, dynamic>{
      'lobby_id': _lobbyId,
      'user_id': _userId,
      'status': status,
      'joined_at': '2026-08-24T18:30:00Z',
    };

void main() {
  late StubAdapter adapter;

  MembershipRepository repositoryWith(Map<String, Stub> responses) {
    adapter = StubAdapter(responses);
    return MembershipRepository(dio: dioWith(adapter));
  }

  group('approve', () {
    const path = '/lobbies/$_lobbyId/members/$_userId/approve';

    test('posts to the approve path and parses the membership', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, _membershipJson()),
      });

      final membership = await repository.approve(_lobbyId, _userId);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, path);
      // None of the admin actions take a body — the verbs are in the path.
      expect(request.data, isNull);

      expect(membership.status, MembershipStatus.approved);
      expect(membership.isApproved, isTrue);
      expect(membership.userId, _userId);
    });

    test('surfaces member_not_found by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(
          404,
          errorBody('member_not_found', 'No such membership request.'),
        ),
      });

      await expectLater(
        repository.approve(_lobbyId, _userId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'member_not_found')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('surfaces admin_only by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(403, errorBody('admin_only', 'Only the organizer can.')),
      });

      await expectLater(
        repository.approve(_lobbyId, _userId),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'admin_only'),
        ),
      );
    });
  });

  group('reject', () {
    const path = '/lobbies/$_lobbyId/members/$_userId/reject';

    test('posts to the reject path and tolerates the empty 204', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(204, <String, dynamic>{}),
      });

      await repository.reject(_lobbyId, _userId);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, path);
    });

    test('surfaces cannot_target_self by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(
          403,
          errorBody('cannot_target_self', 'You cannot reject yourself.'),
        ),
      });

      await expectLater(
        repository.reject(_lobbyId, _userId),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'cannot_target_self',
          ),
        ),
      );
    });
  });

  group('members', () {
    const path = '/lobbies/$_lobbyId/members';

    test('reads the whole roster, with the status as a query param', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(
          200,
          membersJson(<Map<String, dynamic>>[
            memberJson(displayName: 'organizer'),
            memberJson(id: 'u2', displayName: 'climber'),
          ]),
        ),
      });

      final roster = await repository.members(
        _lobbyId,
        status: MembershipStatus.pending,
      );

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.queryParameters['status'], 'pending');
      // Not paginated: no page or page_size goes out, and nothing is unwrapped.
      expect(request.queryParameters.containsKey('page'), isFalse);

      expect(roster, hasLength(2));
      expect(roster.first.user.displayName, 'organizer');
      expect(roster.first.user.email, 'climber@example.com');
    });

    test('asks for the approved roster unless told otherwise', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, membersJson()),
      });

      await repository.members(_lobbyId);

      expect(adapter.requests.single.queryParameters['status'], 'approved');
    });

    test('reads a roster with nobody in it as an empty list', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, membersJson(<Map<String, dynamic>>[])),
      });

      expect(await repository.members(_lobbyId), isEmpty);
    });

    test('surfaces admin_only by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(403, errorBody('admin_only', 'Admins only.')),
      });

      await expectLater(
        repository.members(_lobbyId),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'admin_only'),
        ),
      );
    });
  });

  group('ban', () {
    const path = '/lobbies/$_lobbyId/members/$_userId/ban';

    test('posts to the ban path and parses the banned row', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(200, _membershipJson(status: 'banned')),
      });

      final membership = await repository.ban(_lobbyId, _userId);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, path);
      expect(request.data, isNull);

      // The row surviving is the whole point: it is what blocks a rejoin.
      expect(membership.status, MembershipStatus.banned);
    });

    test('surfaces cannot_target_self by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(
          403,
          errorBody('cannot_target_self', 'You cannot ban yourself.'),
        ),
      });

      await expectLater(
        repository.ban(_lobbyId, _userId),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'cannot_target_self',
          ),
        ),
      );
    });
  });

  group('remove', () {
    const path = '/lobbies/$_lobbyId/members/$_userId';

    test('deletes the row and tolerates the empty 204', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(204, <String, dynamic>{}),
      });

      await repository.remove(_lobbyId, _userId);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, path);
    });

    test('surfaces member_not_found by code', () async {
      final repository = repositoryWith(<String, Stub>{
        path: Stub(404, errorBody('member_not_found', 'No such membership.')),
      });

      await expectLater(
        repository.remove(_lobbyId, _userId),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'member_not_found'),
        ),
      );
    });
  });
}
