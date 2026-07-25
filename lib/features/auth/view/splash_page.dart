import 'package:flutter/material.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';

/// Shown while `AuthStarted` resolves the stored token. The router guard moves
/// away from here as soon as the status is no longer `unknown`.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  /// Must match `color` in flutter_native_splash.yaml, so the handover from the
  /// OS launch screen to this page is invisible.
  static const Color backgroundColor = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
