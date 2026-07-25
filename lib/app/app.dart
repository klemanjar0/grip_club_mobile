import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';

class GripClubApp extends StatelessWidget {
  const GripClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      // Provided from the container so the same instance drives both the UI and
      // the router guard. `AuthStarted` is dispatched in bootstrap().
      value: getIt<AuthBloc>(),
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: AppConfig.isDev,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            // A different accent per flavor makes it obvious at a glance which
            // build is on the device.
            seedColor: AppConfig.isDev
                ? const Color(0xFFE8590C)
                : const Color(0xFF1F6FEB),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        routerConfig: getIt<GoRouter>(),
      ),
    );
  }
}
