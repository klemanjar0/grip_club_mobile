import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/ui/status_views.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/edit_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';
import 'package:grip_club_mobile/features/lobbies/view/widgets/lobby_form.dart';

/// Editing a lobby, for its admin.
///
/// Only what changed is sent, so leaving a field alone cannot overwrite it —
/// see [EditLobbyBloc]. Every approved member is notified of the edit
/// server-side, which is why a save with nothing changed never leaves here.
class EditLobbyPage extends StatelessWidget {
  const EditLobbyPage({required this.lobbyId, this.initialLobby, super.key});

  final String lobbyId;

  /// The lobby the caller already had. Absent on a deep link, in which case the
  /// bloc fetches it — an admin may read their own lobby.
  final Lobby? initialLobby;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditLobbyBloc>(
      create: (_) =>
          getIt<EditLobbyBloc>(param1: lobbyId, param2: initialLobby)
            ..add(const EditLobbyStarted()),
      child: const _EditLobbyView(),
    );
  }
}

class _EditLobbyView extends StatelessWidget {
  const _EditLobbyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit lobby')),
      body: BlocConsumer<EditLobbyBloc, EditLobbyState>(
        listenWhen: (previous, current) =>
            previous.savedLobby != current.savedLobby ||
            (previous.isSubmitting && !current.isSubmitting),
        listener: (context, state) {
          final saved = state.savedLobby;
          if (saved != null) {
            // The name, time and city all show up in the feeds.
            if (state.hasChanges) refreshLobbyFeeds();

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.hasChanges ? 'Changes saved.' : 'Nothing to save.',
                  ),
                ),
              );
            // Handed back so the lobby page can show the new version without a
            // round trip of its own.
            context.pop(saved);
            return;
          }

          // A `validation_failed` is already visible on the fields it names.
          if (state.fieldErrors.isNotEmpty || state.errorMessage == null) {
            return;
          }

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        },
        builder: (context, state) {
          final lobby = state.lobby;

          if (lobby == null) {
            return state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ErrorRetryView(
                    message: state.errorMessage ?? 'Could not load this lobby.',
                    onRetry: () => context.read<EditLobbyBloc>().add(
                      const EditLobbyStarted(),
                    ),
                  );
          }

          return SafeArea(
            child: LobbyForm(
              initial: LobbyDraft.of(lobby),
              currentAvatar: lobby.avatar,
              submitLabel: 'Save changes',
              isSubmitting: state.isSubmitting,
              fieldErrors: state.fieldErrors,
              onSubmit: (draft) =>
                  context.read<EditLobbyBloc>().add(EditLobbySubmitted(draft)),
            ),
          );
        },
      ),
    );
  }
}
