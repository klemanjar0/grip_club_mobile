import 'package:flutter/material.dart';

import 'package:grip_club_mobile/core/format/event_time_format.dart';
import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/ui/avatar_field.dart';
import 'package:grip_club_mobile/core/ui/avatar_image.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';
import 'package:grip_club_mobile/features/lobbies/view/lobby_validators.dart';

/// The lobby form, shared by creating and editing.
///
/// It owns the fields and the client-side rules and nothing else: it hands a
/// normalised [LobbyDraft] to [onSubmit] and lets the page decide whether that
/// becomes a `POST` or a `PATCH`. [fieldErrors] comes back from the server and
/// is placed on the matching fields.
class LobbyForm extends StatefulWidget {
  const LobbyForm({
    required this.submitLabel,
    required this.isSubmitting,
    required this.onSubmit,
    this.initial,
    this.defaultCountry,
    this.defaultCity,
    this.currentAvatar,
    this.fieldErrors = const {},
    super.key,
  });

  final String submitLabel;
  final bool isSubmitting;
  final ValueChanged<LobbyDraft> onSubmit;

  /// Starting values. Absent when creating.
  final LobbyDraft? initial;

  /// The home location saved on the profile, used to open an empty form on the
  /// place the user organises in. Ignored when [initial] is set — a lobby that
  /// exists carries its own country and city.
  final String? defaultCountry;
  final String? defaultCity;

  /// The picture the lobby already has, so the field can show it. Lives outside
  /// [LobbyDraft], which holds what the user typed rather than what is stored.
  final RemoteImage? currentAvatar;

  /// From `validation_failed`, keyed by JSON field name.
  final Map<String, String> fieldErrors;

  @override
  State<LobbyForm> createState() => LobbyFormState();
}

class LobbyFormState extends State<LobbyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _chatLinkController;

  DateTime? _eventTime;
  late LobbyVisibility _visibility;

  /// Held rather than uploaded: nothing leaves the device until the form is
  /// submitted, so backing out costs nothing.
  AvatarSelection _avatar = const AvatarSelection.unchanged();

  /// Set from a server-side `validation_failed`; cleared as soon as the field
  /// is edited again.
  String? _eventTimeError;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _countryController = TextEditingController(
      text: initial?.country ?? widget.defaultCountry ?? '',
    );
    _cityController = TextEditingController(
      text: initial?.city ?? widget.defaultCity ?? '',
    );
    _addressController = TextEditingController(text: initial?.address ?? '');
    _chatLinkController = TextEditingController(text: initial?.chatLink ?? '');
    _eventTime = initial?.eventTime;
    _visibility = initial?.visibility ?? LobbyVisibility.public;
  }

  @override
  void didUpdateWidget(LobbyForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A server-side event_time rejection has no field of its own to land on.
    final serverError = widget.fieldErrors['event_time'];
    if (serverError != null && serverError != _eventTimeError) {
      setState(() => _eventTimeError = serverError);
    }
  }

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
    final existing = _eventTime;

    final date = await showDatePicker(
      context: context,
      initialDate: existing != null && existing.isAfter(now)
          ? existing
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        existing ?? now.add(const Duration(hours: 1)),
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
    final eventTime = _eventTime;

    // An event that has already happened may be edited — the API only rejects
    // an event_time it is *asked* to change to a non-future value. So a time
    // left exactly as it was skips the future check.
    final isUnchangedTime =
        eventTime != null && eventTime == widget.initial?.eventTime;
    final eventTimeError = isUnchangedTime
        ? null
        : LobbyValidators.eventTime(eventTime);

    setState(() => _eventTimeError = eventTimeError);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || eventTimeError != null) return;

    widget.onSubmit(
      LobbyDraft.fromInput(
        name: _nameController.text,
        country: _countryController.text,
        city: _cityController.text,
        eventTime: eventTime!,
        visibility: _visibility,
        description: _descriptionController.text,
        address: _addressController.text,
        chatLink: _chatLinkController.text,
        avatar: _avatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldErrors = widget.fieldErrors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AvatarField(
                  selection: _avatar,
                  current: widget.currentAvatar,
                  enabled: !widget.isSubmitting,
                  shape: AvatarShape.rounded,
                  icon: Icons.image_outlined,
                  size: 96,
                  label: 'Photo',
                  helperText: 'Everyone browsing sees this',
                  errorText: fieldErrors['avatar_file_id'],
                  onChanged: (selection) => setState(() => _avatar = selection),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Thursday night climb',
                    errorText: fieldErrors['name'],
                  ),
                  validator: LobbyValidators.name,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    errorText: fieldErrors['description'],
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
                  decoration: InputDecoration(
                    labelText: 'Country',
                    errorText: fieldErrors['country'],
                  ),
                  validator: LobbyValidators.country,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'City',
                    errorText: fieldErrors['city'],
                  ),
                  validator: LobbyValidators.city,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    helperText: 'Only members see this',
                    errorText: fieldErrors['address'],
                  ),
                  validator: LobbyValidators.address,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _chatLinkController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Chat link',
                    helperText: 'Only members see this',
                    errorText: fieldErrors['chat_link'],
                  ),
                  validator: LobbyValidators.chatLink,
                ),
                const SizedBox(height: 24),
                _VisibilityField(
                  visibility: _visibility,
                  onChanged: (value) => setState(() => _visibility = value),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  child: widget.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.submitLabel),
                ),
              ],
            ),
          ),
        ),
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
