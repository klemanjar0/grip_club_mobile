import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/create_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobby_validators.dart';

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

class _CreateLobbyView extends StatefulWidget {
  const _CreateLobbyView();

  @override
  State<_CreateLobbyView> createState() => _CreateLobbyViewState();
}

class _CreateLobbyViewState extends State<_CreateLobbyView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _chatLinkController = TextEditingController();

  DateTime? _eventTime;
  LobbyVisibility _visibility = LobbyVisibility.public;

  /// Set from a server-side `validation_failed`; cleared as soon as the field
  /// is edited again.
  String? _eventTimeError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _chatLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickEventTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eventTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _eventTime ?? now.add(const Duration(hours: 1)),
      ),
    );

    if (time == null) return;

    setState(() {
      _eventTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _eventTimeError = null;
    });
  }

  void _submit() {
    final eventTimeError = LobbyValidators.eventTime(_eventTime);
    setState(() => _eventTimeError = eventTimeError);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || eventTimeError != null) return;

    context.read<CreateLobbyBloc>().add(
      CreateLobbySubmitted(
        name: _nameController.text,
        country: _countryController.text,
        city: _cityController.text,
        eventTime: _eventTime!,
        visibility: _visibility,
        description: _descriptionController.text,
        address: _addressController.text,
        chatLink: _chatLinkController.text,
      ),
    );
  }

  /// Puts a server-side validation failure on the field it belongs to.
  ///
  /// Only `event_time` has no `TextFormField` of its own to carry an error, so
  /// it is placed by hand. Text fields re-validate against the same limits the
  /// server just enforced. Anything left unexplained goes to a snackbar.
  void _onSubmitFailed(CreateLobbyState state) {
    final eventTimeError = state.fieldErrors['event_time'];
    if (eventTimeError != null) {
      setState(() => _eventTimeError = eventTimeError);
    }

    final placedOnFields =
        _formKey.currentState?.validate() == false || eventTimeError != null;

    if (placedOnFields) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Could not create the lobby.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
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

          _onSubmitFailed(state);
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'Thursday night climb',
                          ),
                          validator: LobbyValidators.name,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                          ),
                          validator: LobbyValidators.description,
                        ),
                        const SizedBox(height: 16),
                        _EventTimeField(
                          eventTime: _eventTime,
                          errorText: _eventTimeError,
                          onPressed: _pickEventTime,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _countryController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                          ),
                          validator: LobbyValidators.country,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: LobbyValidators.city,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            helperText: 'Only members see this',
                          ),
                          validator: LobbyValidators.address,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _chatLinkController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Chat link',
                            helperText: 'Only members see this',
                          ),
                          validator: LobbyValidators.chatLink,
                        ),
                        const SizedBox(height: 24),
                        _VisibilityField(
                          visibility: _visibility,
                          onChanged: (value) =>
                              setState(() => _visibility = value),
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: state.isSubmitting ? null : _submit,
                          child: state.isSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create lobby'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Date and time in one tap-through, rendered as a form field so its error sits
/// where every other field's does.
class _EventTimeField extends StatelessWidget {
  const _EventTimeField({
    required this.eventTime,
    required this.errorText,
    required this.onPressed,
  });

  final DateTime? eventTime;
  final String? errorText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'When',
        errorText: errorText,
        suffixIcon: const Icon(Icons.event),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            eventTime == null
                ? 'Pick a date and time'
                : formatEventTime(eventTime!),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: eventTime == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityField extends StatelessWidget {
  const _VisibilityField({required this.visibility, required this.onChanged});

  final LobbyVisibility visibility;
  final ValueChanged<LobbyVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPrivate = visibility == LobbyVisibility.private;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LobbyVisibility>(
          segments: const [
            ButtonSegment<LobbyVisibility>(
              value: LobbyVisibility.public,
              icon: Icon(Icons.public),
              label: Text('Public'),
            ),
            ButtonSegment<LobbyVisibility>(
              value: LobbyVisibility.private,
              icon: Icon(Icons.lock_outline),
              label: Text('Private'),
            ),
          ],
          selected: <LobbyVisibility>{visibility},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 8),
        Text(
          isPrivate
              ? 'People request to join and you approve them.'
              : 'Anyone can find this lobby and join instantly.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
