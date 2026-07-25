import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/view/auth_validators.dart';

/// Sign-up. Registering returns a live session, so a success needs no
/// navigation here — the router guard reacts to `AuthStatus.authenticated`.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Server-side rejections shown on the field they belong to. Cleared as soon
  // as the user edits that field, so a stale error never blocks a retry.
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  /// Turns a failed attempt into field errors where the API gave us enough to
  /// place them, and a snackbar where it did not.
  void _onSubmitFailed(BuildContext context, AuthState state) {
    final emailError =
        state.fieldErrors['email'] ??
        (state.errorCode == 'email_taken'
            ? 'That email is already registered'
            : null);
    final passwordError = state.fieldErrors['password'];

    if (emailError == null && passwordError == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      return;
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    // Re-run validation so the messages above appear under their fields.
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          // Only a submission that just came back failed — not the error the
          // login screen may already have been showing.
          listenWhen: (previous, current) =>
              previous.isSubmitting &&
              !current.isSubmitting &&
              current.errorMessage != null,
          listener: _onSubmitFailed,
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.newUsername],
                          enabled: !state.isSubmitting,
                          onChanged: (_) => _clearFieldError(() {
                            _emailError = null;
                          }, _emailError),
                          validator: (value) =>
                              AuthValidators.email(value) ?? _emailError,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText:
                                'At least '
                                '${AuthValidators.minPasswordLength} characters',
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !state.isSubmitting,
                          onChanged: (_) => _clearFieldError(() {
                            _passwordError = null;
                          }, _passwordError),
                          validator: (value) =>
                              AuthValidators.newPassword(value) ??
                              _passwordError,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !state.isSubmitting,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => AuthValidators.confirmPassword(
                            value,
                            _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state.isSubmitting ? null : _submit,
                          child: state.isSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Rebuilds only when there is actually an error to drop.
  void _clearFieldError(VoidCallback clear, String? current) {
    if (current == null) return;
    setState(clear);
  }
}
