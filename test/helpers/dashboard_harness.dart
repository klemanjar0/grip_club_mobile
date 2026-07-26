import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/images/photo_picker.dart';
import 'package:grip_club_mobile/core/network/authorized_images.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/create_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/edit_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_detail_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/bloc/join_request_bloc.dart';
import 'package:grip_club_mobile/features/members/bloc/lobby_members_bloc.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_bloc.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';
import 'package:grip_club_mobile/features/profile/bloc/profile_bloc.dart';
import 'package:grip_club_mobile/features/files/data/avatar_uploader.dart';
import 'package:grip_club_mobile/features/profile/data/user_repository.dart';

import 'avatar_fixtures.dart';

class MockLobbyRepository extends Mock implements LobbyRepository {}

class MockMembershipRepository extends Mock implements MembershipRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockUserRepository extends Mock implements UserRepository {}

/// The mocks behind a registered dashboard, so a test can re-stub them.
class DashboardMocks {
  const DashboardMocks({
    required this.lobbies,
    required this.memberships,
    required this.notifications,
    required this.users,
  });

  final MockLobbyRepository lobbies;
  final MockMembershipRepository memberships;
  final MockNotificationRepository notifications;
  final MockUserRepository users;
}

PageEnvelope<T> _emptyPage<T>() =>
    PageEnvelope<T>(items: const [], page: 0, pageSize: 10, hasNext: false);

/// Registers everything the dashboard pages resolve from [getIt], backed by
/// mocks that answer with empty feeds.
///
/// Mirrors `configureDependencies` for the graph below the repositories, minus
/// the Dio and SharedPreferences that a widget test has no use for. Pair with
/// `getIt.reset()` in `tearDown`.
DashboardMocks registerDashboardStubs({AuthRepository? auth}) {
  final lobbies = MockLobbyRepository();
  final memberships = MockMembershipRepository();
  final notifications = MockNotificationRepository();
  final users = MockUserRepository();

  when(
    () => lobbies.browse(
      city: any(named: 'city'),
      within: any(named: 'within'),
      page: any(named: 'page'),
    ),
  ).thenAnswer((_) async => _emptyPage<Lobby>());
  when(
    () => lobbies.myLobbies(page: any(named: 'page')),
  ).thenAnswer((_) async => _emptyPage<Lobby>());
  when(
    () => notifications.feed(
      unreadOnly: any(named: 'unreadOnly'),
      page: any(named: 'page'),
    ),
  ).thenAnswer((_) async => _emptyPage<AppNotification>());
  when(notifications.unreadCount).thenAnswer((_) async => 0);

  // Nothing here has a session or a platform channel, so the two image
  // services are stubs: one hands back bytes that decode, the other is only
  // reached if a test taps the picker.
  final avatars = avatarUploader();

  getIt
    ..registerSingleton<AuthorizedImages>(stubbedImages())
    ..registerSingleton<PhotoPicker>(MockPhotoPicker())
    ..registerSingleton<AvatarUploader>(avatars)
    ..registerSingleton<LobbyRepository>(lobbies)
    ..registerSingleton<MembershipRepository>(memberships)
    ..registerSingleton<NotificationRepository>(notifications)
    ..registerSingleton<UserRepository>(users)
    ..registerLazySingleton<LobbiesBloc>(
      () => LobbiesBloc(repository: lobbies, memberships: memberships),
    )
    ..registerLazySingleton<MyLobbiesBloc>(
      () => MyLobbiesBloc(repository: lobbies, memberships: memberships),
    )
    ..registerLazySingleton<NotificationsBadgeBloc>(
      () => NotificationsBadgeBloc(repository: notifications),
    )
    ..registerLazySingleton<NotificationsBloc>(
      () => NotificationsBloc(
        repository: notifications,
        badge: getIt<NotificationsBadgeBloc>(),
      ),
    )
    ..registerFactory<CreateLobbyBloc>(
      () => CreateLobbyBloc(repository: lobbies, avatars: avatars),
    )
    ..registerFactoryParam<EditLobbyBloc, String, Lobby?>(
      (lobbyId, initialLobby) => EditLobbyBloc(
        lobbyId: lobbyId,
        repository: lobbies,
        avatars: avatars,
        initialLobby: initialLobby,
      ),
    )
    ..registerFactoryParam<LobbyDetailBloc, String, Lobby?>(
      (lobbyId, initialLobby) => LobbyDetailBloc(
        lobbyId: lobbyId,
        lobbies: lobbies,
        memberships: memberships,
        initialLobby: initialLobby,
      ),
    )
    ..registerFactoryParam<LobbyMembersBloc, String, void>(
      (lobbyId, _) =>
          LobbyMembersBloc(lobbyId: lobbyId, memberships: memberships),
    )
    ..registerFactoryParam<JoinRequestBloc, String, String>(
      (lobbyId, userId) => JoinRequestBloc(
        lobbyId: lobbyId,
        userId: userId,
        memberships: memberships,
      ),
    );

  if (auth != null) {
    getIt
      ..registerSingleton<AuthRepository>(auth)
      ..registerFactory<ProfileBloc>(
        () => ProfileBloc(users: users, auth: auth, avatars: avatars),
      );
  }

  return DashboardMocks(
    lobbies: lobbies,
    memberships: memberships,
    notifications: notifications,
    users: users,
  );
}
