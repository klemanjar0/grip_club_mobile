import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:grip_club_mobile/app/app.dart';
import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';

/// Shared startup path for every flavor entrypoint.
///
/// [expectedFlavor] is the flavor the entrypoint was written for; it is compared
/// against `FLAVOR` from the env JSON so a mismatched
/// `--dart-define-from-file` is caught immediately instead of pointing a prod
/// build at the dev API.
Future<void> bootstrap({required Flavor expectedFlavor}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final configError = _validateConfig(expectedFlavor);
  if (configError != null) {
    // Deliberately not an assert: an assert would throw before runApp and leave
    // a blank screen in debug. Printing plus a full-screen message works the
    // same way in every build mode.
    debugPrint('Configuration error: $configError');
    runApp(_ConfigErrorApp(message: configError));
    return;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  await configureDependencies();
  getIt<AuthBloc>().add(const AuthStarted());

  runApp(const GripClubApp());
}

String? _validateConfig(Flavor expectedFlavor) {
  if (AppConfig.apiBaseUrl.isEmpty) {
    return 'API_BASE_URL is empty. Pass the env file, e.g. '
        '--dart-define-from-file=env/${expectedFlavor.name}.json';
  }
  if (AppConfig.flavor != expectedFlavor) {
    return 'Flavor mismatch: this entrypoint expects "${expectedFlavor.name}" '
        'but the env file declares FLAVOR="${AppConfig.flavor.name}".';
  }
  return null;
}

/// Minimal red screen for a misconfigured build — never reached in a correct run.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Configuration error\n\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
