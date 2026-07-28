import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';

/// Shown when the startup check could not reach the backend. The router guard
/// holds the app here for as long as the status is `unavailable`.
///
/// Retrying re-dispatches [AuthStarted], which puts the status back to `unknown`
/// — the guard then returns to the splash screen and the launch flow runs again
/// from the top. There is no `context.go` here for the same reason there is none
/// in the rest of the auth flow.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The transport-level reason, when there is one. A dead connection and a
    // dead server produce the same screen, so this line is what stops it from
    // telling an offline user that the servers are down.
    final reason = context.select(
      (AuthBloc bloc) => bloc.state.status == AuthStatus.unavailable
          ? bloc.state.errorMessage
          : null,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text('Under maintenance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'The app is unavailable right now. Please try again in a '
                  'few minutes.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () =>
                      context.read<AuthBloc>().add(const AuthStarted()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
