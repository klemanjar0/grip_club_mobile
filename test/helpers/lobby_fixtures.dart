import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// A `LobbyResponse` as the server sends it, with the viewer block overridable
/// per test.
Map<String, dynamic> lobbyJson({
  String id = 'a1b2c3d4-0000-4000-8000-000000000001',
  String name = 'Thursday night climb',
  String city = 'Kyiv',
  String visibility = 'public',
  String role = 'outsider',
  String? membershipStatus,
  bool canJoin = true,
  String? address,
  String? chatLink,
  int approvedCount = 3,
  String eventTime = '2099-08-24T18:30:00Z',
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'description': 'Bring chalk.',
  'country': 'Ukraine',
  'city': city,
  'address': address,
  'event_time': eventTime,
  'visibility': visibility,
  'approved_count': approvedCount,
  'chat_link': chatLink,
  'creator': <String, dynamic>{
    'id': 'c0000000-0000-4000-8000-000000000001',
    'display_name': 'organizer',
  },
  'viewer': <String, dynamic>{
    'role': role,
    'membership_status': membershipStatus,
    'can_join': canJoin,
  },
  'created_at': '2026-08-01T10:00:00Z',
  'updated_at': '2026-08-02T10:00:00Z',
};

/// A `PageEnvelope<LobbyResponse>`.
Map<String, dynamic> lobbyPageJson({
  List<Map<String, dynamic>>? items,
  int page = 0,
  bool hasNext = false,
}) => <String, dynamic>{
  'items': items ?? <Map<String, dynamic>>[lobbyJson()],
  'page': page,
  'page_size': 10,
  'has_next': hasNext,
};

/// A parsed [Lobby], for the bloc tests that never touch JSON.
Lobby lobby({
  String id = 'a1b2c3d4-0000-4000-8000-000000000001',
  String name = 'Thursday night climb',
  String role = 'outsider',
  bool canJoin = true,
}) =>
    Lobby.fromJson(lobbyJson(id: id, name: name, role: role, canJoin: canJoin));
