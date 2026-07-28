import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/ui/avatar_field.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/auth/view/auth_validators.dart';
import 'package:grip_club_mobile/features/profile/bloc/profile_bloc.dart';
import 'package:grip_club_mobile/features/profile/view/password_section.dart';

/// Profile tab: who you are, the defaults the Lobbies tab browses with, your
/// password, and the way out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (_) => getIt<ProfileBloc>(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  void _tell(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: BlocListener<ProfileBloc, ProfileState>(
          listenWhen: (previous, current) =>
              (previous.outcome != current.outcome &&
                  current.outcome != null) ||
              (previous.errorMessage != current.errorMessage &&
                  current.errorMessage != null),
          listener: (context, state) {
            final outcome = state.outcome;
            if (outcome == null) {
              // A `validation_failed` is already on the fields it names; a
              // failed upload or attach has no field to land on.
              if (state.fieldErrors.isEmpty) {
                _tell(context, state.errorMessage!);
              }
              return;
            }

            // The saved profile is the app's copy of the user: hand it to the
            // AuthBloc so the lobby filters and the picture pick up the change.
            final updated = state.updatedUser;
            if (updated != null) {
              context.read<AuthBloc>().add(AuthUserUpdated(updated));
            }

            _tell(context, switch (outcome) {
              ProfileOutcome.preferencesSaved => 'Preferences saved.',
              ProfileOutcome.avatarSaved => 'Photo updated.',
              ProfileOutcome.avatarRemoved => 'Photo removed.',
              ProfileOutcome.passwordChanged =>
                'Password changed. Other devices were signed out.',
            });
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (user != null) ...[
                _ProfileHeader(user: user),
                const SizedBox(height: 24),
                _PreferencesSection(user: user),
              ],
              const SizedBox(height: 24),
              const PasswordSection(),
              const SizedBox(height: 24),
              const _SessionSection(),
              if (AppConfig.isDev) ...[
                const SizedBox(height: 32),
                const _DevConfigSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Who you are, and the one control that changes your picture.
///
/// The picture saves the moment it is picked rather than waiting for the Save
/// button below — it is not part of the preferences form, and pairing an image
/// with a text form would mean an upload the user cannot see the result of.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (ProfileBloc bloc) => bloc.state.isSavingAvatar,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AvatarField(
          // Nothing is held between taps: each pick is saved on the spot, and
          // what comes back on the [User] is what the field renders next.
          selection: const AvatarSelection.unchanged(),
          current: user.avatar,
          isBusy: isSaving,
          size: 72,
          emptyLabel: 'Add a photo',
          onChanged: (selection) => context.read<ProfileBloc>().add(
            ProfileAvatarSubmitted(selection),
          ),
          label: user.displayName,
          helperText: user.email,
        ),
      ),
    );
  }
}

/// `PATCH /me`. Every field is independent, so the form submits all of them and
/// lets the server keep whatever did not change.
class _PreferencesSection extends StatefulWidget {
  const _PreferencesSection({required this.user});

  final User user;

  @override
  State<_PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends State<_PreferencesSection> {
  static const Map<String, String> _timeFilters = {
    'day': 'Today',
    'week': 'This week',
    'month': 'This month',
    'all': 'Any time',
  };

  static const Map<String, String> _locales = {
    'en': 'English',
    'ru': 'Русский',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _timezoneController;
  late String _locale;
  late String _timeFilter;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _countryController = TextEditingController(text: widget.user.country);
    _cityController = TextEditingController(text: widget.user.city);
    _timezoneController = TextEditingController(text: widget.user.timezone);
    _locale = _locales.containsKey(widget.user.locale)
        ? widget.user.locale
        : 'en';
    _timeFilter = _timeFilters.containsKey(widget.user.timeFilter)
        ? widget.user.timeFilter
        : 'all';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<ProfileBloc>().add(
      ProfilePreferencesSubmitted(
        displayName: _displayNameController.text.trim(),
        locale: _locale,
        timezone: _timezoneController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        timeFilter: _timeFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'Leave empty to use your email name',
                ),
                validator: (value) => (value ?? '').trim().length > 64
                    ? 'Keep it under 64 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              // The home location. The pair fills in a new lobby's country and
              // city; the city alone is also what the Lobbies tab browses.
              TextFormField(
                controller: _countryController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Country',
                  helperText: 'Fills in a new lobby',
                  errorText: state.fieldErrors['country'],
                ),
                validator: AuthValidators.place,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'City',
                  helperText: 'Browsed by default; empty means every city',
                  errorText: state.fieldErrors['city'],
                ),
                validator: AuthValidators.place,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timezoneController,
                decoration: InputDecoration(
                  labelText: 'Time zone',
                  helperText: 'IANA name, e.g. Europe/Kyiv',
                  // The server owns the tzdata list, so an unknown zone can
                  // only be reported after the round trip.
                  errorText: state.fieldErrors['timezone'],
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceField<String>(
                label: 'Language',
                value: _locale,
                options: _locales,
                onChanged: (value) => setState(() => _locale = value),
              ),
              const SizedBox(height: 16),
              _ChoiceField<String>(
                label: 'Default time window',
                value: _timeFilter,
                options: _timeFilters,
                onChanged: (value) => setState(() => _timeFilter = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.isBusy ? null : _save,
                child: state.isSavingPreferences
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save preferences'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChoiceField<T> extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _SessionSection extends StatelessWidget {
  const _SessionSection();

  Future<void> _confirmLogoutAll(BuildContext context) async {
    final bloc = context.read<AuthBloc>();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text(
          'Every device signs out, including this one. You will need to sign '
          'in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut ?? false) bloc.add(const AuthLogoutAllRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Session', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.devices_other),
          title: const Text('Sign out everywhere'),
          subtitle: const Text('Revokes every session, this one included'),
          onTap: () => _confirmLogoutAll(context),
        ),
      ],
    );
  }
}

/// Dev builds only — the flavor wiring is easier to trust when it is visible.
class _DevConfigSection extends StatelessWidget {
  const _DevConfigSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Build', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _ConfigTile(label: 'Flavor', value: AppConfig.flavor.name),
        _ConfigTile(label: 'API base URL', value: AppConfig.apiBaseUrl),
        _ConfigTile(
          label: 'HTTP logging',
          value: AppConfig.enableHttpLogging ? 'on' : 'off',
        ),
        _ConfigTile(
          label: 'Connect timeout',
          value: '${AppConfig.connectTimeoutMs} ms',
        ),
      ],
    );
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(value),
    );
  }
}
