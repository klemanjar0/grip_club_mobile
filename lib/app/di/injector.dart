import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/app/router/app_router.dart';
import 'package:grip_club_mobile/core/network/dio_client.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/create_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_detail_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_badge_bloc.dart';
import 'package:grip_club_mobile/features/notifications/bloc/notifications_bloc.dart';
import 'package:grip_club_mobile/features/notifications/data/notification_repository.dart';
import 'package:grip_club_mobile/features/profile/bloc/profile_bloc.dart';
import 'package:grip_club_mobile/features/profile/data/user_repository.dart';

final GetIt getIt = GetIt.instance;

/// Wires up the object graph. Called once from `bootstrap()` before `runApp`.
Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();

  getIt
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerSingleton<TokenStorage>(TokenStorage(preferences))
    ..registerSingleton<Dio>(
      createDio(
        tokenStorage: getIt<TokenStorage>(),
        // Resolved lazily: Dio is built before AuthBloc exists.
        onUnauthorized: () => getIt<AuthBloc>().add(const AuthSessionExpired()),
      ),
    )
    ..registerSingleton<AuthRepository>(
      AuthRepository(dio: getIt<Dio>(), tokenStorage: getIt<TokenStorage>()),
    )
    ..registerSingleton<LobbyRepository>(LobbyRepository(dio: getIt<Dio>()))
    ..registerSingleton<MembershipRepository>(
      MembershipRepository(dio: getIt<Dio>()),
    )
    ..registerSingleton<NotificationRepository>(
      NotificationRepository(dio: getIt<Dio>()),
    )
    ..registerSingleton<UserRepository>(UserRepository(dio: getIt<Dio>()))
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(repository: getIt<AuthRepository>()),
    )
    // The router holds a subscription to the bloc, so it is a singleton too —
    // rebuilding it would reset the navigation stack.
    ..registerLazySingleton<GoRouter>(() => createRouter(getIt<AuthBloc>()))
    // Tab-level blocs are singletons: a tab must survive being switched away
    // from, and creating a lobby has to reach feeds it does not sit inside.
    // Mount them with `BlocProvider.value` so no page closes them, and clear
    // them on sign-out — see [clearSessionCaches].
    ..registerLazySingleton<LobbiesBloc>(
      () => LobbiesBloc(repository: getIt<LobbyRepository>()),
    )
    ..registerLazySingleton<MyLobbiesBloc>(
      () => MyLobbiesBloc(repository: getIt<LobbyRepository>()),
    )
    ..registerLazySingleton<NotificationsBadgeBloc>(
      () => NotificationsBadgeBloc(repository: getIt<NotificationRepository>()),
    )
    ..registerLazySingleton<NotificationsBloc>(
      () => NotificationsBloc(
        repository: getIt<NotificationRepository>(),
        badge: getIt<NotificationsBadgeBloc>(),
      ),
    )
    // Page-scoped blocs: mounted with `BlocProvider(create:)`, which closes
    // them with the page.
    ..registerFactory<CreateLobbyBloc>(
      () => CreateLobbyBloc(repository: getIt<LobbyRepository>()),
    )
    ..registerFactoryParam<LobbyDetailBloc, String, void>(
      (lobbyId, _) => LobbyDetailBloc(
        lobbyId: lobbyId,
        lobbies: getIt<LobbyRepository>(),
        memberships: getIt<MembershipRepository>(),
      ),
    )
    ..registerFactory<ProfileBloc>(
      () => ProfileBloc(
        users: getIt<UserRepository>(),
        auth: getIt<AuthRepository>(),
      ),
    );
}

/// Pulls both lobby feeds again.
///
/// Creating a lobby changes what belongs in each feed, and the create form is
/// pushed above the tab shell, so it cannot reach them through the widget tree.
void refreshLobbyFeeds() {
  getIt<LobbiesBloc>().add(const LobbyFeedRefreshed());
  getIt<MyLobbiesBloc>().add(const LobbyFeedRefreshed());
}

/// Empties everything that belongs to the signed-in user.
///
/// The tab blocs outlive a session, so without this the next person to sign in
/// on this device would briefly see the previous one's lobbies. Called from the
/// app root the moment the session ends.
void clearSessionCaches() {
  getIt<LobbiesBloc>().add(const LobbyFeedCleared());
  getIt<MyLobbiesBloc>().add(const LobbyFeedCleared());
  getIt<NotificationsBloc>().add(const NotificationsCleared());
  getIt<NotificationsBadgeBloc>().add(const NotificationsBadgeCleared());
}
