import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

import '../../helpers/avatar_fixtures.dart';
import '../../helpers/lobby_fixtures.dart';

void main() {
  group('fromJson', () {
    test('reads the id and the url', () {
      final image = RemoteImage.fromJson(avatarJson(id: 'file-id'));

      expect(image?.id, 'file-id');
      expect(image?.url, contains('file-id'));
    });

    test('reads an unset avatar as no image', () {
      // The key is always present and `null` until one is set.
      expect(RemoteImage.fromJson(null), isNull);
    });

    test('reads a half-built block as no image rather than a broken one', () {
      expect(RemoteImage.fromJson(<String, dynamic>{'id': 'file-id'}), isNull);
      expect(
        RemoteImage.fromJson(<String, dynamic>{'id': '', 'url': ''}),
        isNull,
      );
    });
  });

  test('a user carries its avatar', () {
    final user = User.fromJson(<String, dynamic>{
      'id': 'u1',
      'email': 'rider@example.com',
      'display_name': 'climber',
      'avatar': avatarJson(id: 'user-file'),
    });

    expect(user.avatar?.id, 'user-file');
  });

  test('a lobby carries its avatar, and shows none when it has none', () {
    final withImage = Lobby.fromJson(<String, dynamic>{
      ...lobbyJson(),
      'avatar': avatarJson(id: 'lobby-file'),
    });

    expect(withImage.avatar?.id, 'lobby-file');
    expect(Lobby.fromJson(lobbyJson()).avatar, isNull);
  });

  test('joining a lobby keeps the picture on the local copy', () {
    final joined = Lobby.fromJson(<String, dynamic>{
      ...lobbyJson(),
      'avatar': avatarJson(id: 'lobby-file'),
    }).withMembership(MembershipStatus.approved);

    expect(joined.avatar?.id, 'lobby-file');
  });
}
