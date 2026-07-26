import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/members/bloc/join_request_bloc.dart';

/// Opens the approve / reject sheet for one pending request.
///
/// Resolves to the verdict the admin reached, or `null` if they dismissed the
/// sheet without deciding — a `join_request` notification stays actionable, so
/// backing out costs nothing.
Future<JoinRequestDecision?> showJoinRequestSheet(
  BuildContext context, {
  required String lobbyId,
  required String userId,
  required String applicantName,
  required String lobbyName,
}) => showModalBottomSheet<JoinRequestDecision>(
  context: context,
  isScrollControlled: true,
  // Dismissing mid-call is safe to allow: closing the bloc with the sheet
  // cancels its emitter, so the in-flight verdict lands server-side and the
  // pop that would follow it is simply never emitted.
  builder: (sheetContext) => BlocProvider<JoinRequestBloc>(
    create: (_) => getIt<JoinRequestBloc>(param1: lobbyId, param2: userId),
    child: _JoinRequestSheet(
      applicantName: applicantName,
      lobbyName: lobbyName,
    ),
  ),
);

class _JoinRequestSheet extends StatelessWidget {
  const _JoinRequestSheet({
    required this.applicantName,
    required this.lobbyName,
  });

  final String applicantName;
  final String lobbyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<JoinRequestBloc, JoinRequestState>(
      listenWhen: (previous, current) =>
          previous.decision != current.decision ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final decision = state.decision;
        if (decision != null) Navigator.of(context).pop(decision);
      },
      builder: (context, state) {
        // The request is gone — withdrawn, or answered from another device.
        // Saying so beats both a raw `member_not_found` and a sheet that closes
        // itself for no visible reason.
        final settled = state.isSettledElsewhere;
        final error = settled ? null : state.errorMessage;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: const Icon(Icons.person_add_alt, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicantName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'wants to join $lobbyName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  settled
                      ? 'This request is no longer waiting — it was withdrawn, '
                            'or another admin already answered it.'
                      : 'Approving lets them see the exact address and the '
                            'group chat. Declining is not final — they can ask '
                            'again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (settled)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  )
                else ...[
                  FilledButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.read<JoinRequestBloc>().add(
                            const JoinRequestApprovalRequested(),
                          ),
                    child: state.pending == JoinRequestDecision.approved
                        ? const _ButtonSpinner()
                        : const Text('Approve'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.read<JoinRequestBloc>().add(
                            const JoinRequestRejectionRequested(),
                          ),
                    child: state.pending == JoinRequestDecision.rejected
                        ? const _ButtonSpinner()
                        : const Text('Decline'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
