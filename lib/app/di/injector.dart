import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/app/router/app_router.dart';
import 'package:grip_club_mobile/core/network/dio_client.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';

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
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(repository: getIt<AuthRepository>()),
    )
    // The router holds a subscription to the bloc, so it is a singleton too —
    // rebuilding it would reset the navigation stack.
    ..registerLazySingleton<GoRouter>(() => createRouter(getIt<AuthBloc>()));
}
