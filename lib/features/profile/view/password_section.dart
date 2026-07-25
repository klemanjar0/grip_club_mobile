import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/features/auth/view/auth_validators.dart';
import 'package:grip_club_mobile/features/profile/bloc/profile_bloc.dart';

/// `PATCH /auth/password`, collapsed until asked for.
///
/// Changing the password signs every *other* device out; this one keeps its
/// token, so there is no re-login afterwards.
class PasswordSection extends StatefulWidget {
  const PasswordSection({super.key});

  @override
  State<PasswordSection> createState() => _PasswordSectionState();
}

class _PasswordSectionState extends State<PasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isExpanded = false;

  /// From `401 invalid_credentials`; cleared on the next attempt.
  String? _currentPasswordError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _currentPasswordError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<ProfileBloc>().add(
      ProfilePasswordSubmitted(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      ),
    );
  }

  void _onResult(ProfileState state) {
    if (state.outcome == ProfileOutcome.passwordChanged) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() => _isExpanded = false);
      return;
    }

    if (state.errorMessage == null) return;

    // A wrong current password belongs on that field, not in a snackbar.
    setState(() {
      _currentPasswordError = state.errorCode == 'invalid_credentials'
          ? state.errorMessage
          : null;
    });

    final newPasswordError = state.fieldErrors['new_password'];
    if (_currentPasswordError == null && newPasswordError == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }

    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (previous, current) =>
          previous.isChangingPassword && !current.isChangingPassword,
      listener: (context, state) => _onResult(state),
      builder: (context, state) {
        if (!_isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Security', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _isExpanded = true),
              ),
            ],
          );
        }

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Change password',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: state.isChangingPassword
                        ? null
                        : () => setState(() => _isExpanded = false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  errorText: _currentPasswordError,
                ),
                validator: AuthValidators.presentPassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  errorText: state.fieldErrors['new_password'],
                ),
                validator: AuthValidators.newPassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repeat new password',
                ),
                validator: (value) =>
                    AuthValidators.confirmPassword(value, _newController.text),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.isBusy ? null : _submit,
                child: state.isChangingPassword
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        );
      },
    );
  }
}
