import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';

/// One row of a `MembersResponse`.
Map<String, dynamic> memberJson({
  String id = 'u0000000-0000-4000-8000-000000000002',
  String displayName = 'climber',
  String email = 'climber@example.com',
  String status = 'approved',
  String joinedAt = '2026-08-20T10:00:00Z',
}) => <String, dynamic>{
  'user': <String, dynamic>{
    'id': id,
    'display_name': displayName,
    'email': email,
  },
  'status': status,
  'joined_at': joinedAt,
};

/// A whole `MembersResponse`. Deliberately not a page envelope — this endpoint
/// answers with the entire roster.
Map<String, dynamic> membersJson([List<Map<String, dynamic>>? items]) =>
    <String, dynamic>{
      'items': items ?? <Map<String, dynamic>>[memberJson()],
    };

/// A parsed [LobbyMember], for the tests that never touch JSON.
LobbyMember member({
  String id = 'u0000000-0000-4000-8000-000000000002',
  String displayName = 'climber',
  String status = 'approved',
}) => LobbyMember.fromJson(
  memberJson(id: id, displayName: displayName, status: status),
);
