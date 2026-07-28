import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/create_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/view/widgets/lobby_form.dart';

/// The `+` in the middle of the tab bar. Pushed over the shell.
class CreateLobbyPage extends StatelessWidget {
  const CreateLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateLobbyBloc>(
      create: (_) => getIt<CreateLobbyBloc>(),
      child: const _CreateLobbyView(),
    );
  }
}

class _CreateLobbyView extends StatelessWidget {
  const _CreateLobbyView();

  @override
  Widget build(BuildContext context) {
    // The home location saved at sign-up or on the profile. Filling the two
    // fields in is what "defaults" means here: the form always sends both, so
    // the server's own defaulting — which only applies when *neither* is sent —
    // never gets the chance to.
    final home = context.select((AuthBloc bloc) => bloc.state.user);

    return Scaffold(
      appBar: AppBar(title: const Text('New lobby')),
      body: BlocConsumer<CreateLobbyBloc, CreateLobbyState>(
        listenWhen: (previous, current) =>
            previous.isSubmitting && !current.isSubmitting,
        listener: (context, state) {
          final created = state.createdLobby;
          if (created != null) {
            // The new lobby belongs in both feeds, and this page sits above the
            // shell so it cannot reach them through the tree.
            refreshLobbyFeeds();

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('“${created.name}” is live.')),
              );
            context.pop();
            return;
          }

          // A `validation_failed` is already visible on the fields it names;
          // only a failure the form cannot show needs a snackbar.
          if (state.fieldErrors.isNotEmpty) return;

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ?? 'Could not create the lobby.',
                ),
              ),
            );
        },
        builder: (context, state) => SafeArea(
          child: LobbyForm(
            submitLabel: 'Create lobby',
            defaultCountry: home?.country,
            defaultCity: home?.city,
            isSubmitting: state.isSubmitting,
            fieldErrors: state.fieldErrors,
            onSubmit: (draft) => context.read<CreateLobbyBloc>().add(
              CreateLobbySubmitted(draft),
            ),
          ),
        ),
      ),
    );
  }
}
