import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/view/auth_validators.dart';

/// The two halves of the sign-up form.
///
/// Credentials and home location are asked for one at a time: they are answered
/// from different places in the head, and a single column of five fields reads
/// as a wall.
enum _RegisterStep {
  account,
  location;

  bool get isLast => this == _RegisterStep.location;
}

/// Sign-up. Registering returns a live session, so a success needs no
/// navigation here — the router guard reacts to `AuthStatus.authenticated`.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // One form per step: a horizontal [Stepper] only mounts the step on screen,
  // so a single key would validate whichever half happens to be built.
  final _accountFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  _RegisterStep _step = _RegisterStep.account;

  // Server-side rejections, shown as `errorText` rather than through the
  // validators: a step that was off screen when the answer came back is rebuilt
  // from scratch, and a validator only speaks when it is asked to. Cleared as
  // soon as the user edits the field, so a stale error never blocks a retry.
  String? _emailError;
  String? _passwordError;
  String? _countryError;
  String? _cityError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _goTo(_RegisterStep step) {
    if (step == _step) return;

    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  /// Account → location. The credentials are checked here so a typo is caught
  /// before the second step rather than after it.
  void _continue() {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;
    // A rejection the server made and the user has not answered yet.
    if (_emailError != null || _passwordError != null) return;

    _goTo(_RegisterStep.location);
  }

  void _submit() {
    if (!(_locationFormKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    // Both location fields are optional: left empty they are dropped from the
    // request and the account is created without a home location.
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
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
    final countryError = state.fieldErrors['country'];
    final cityError = state.fieldErrors['city'];

    if (emailError == null &&
        passwordError == null &&
        countryError == null &&
        cityError == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      return;
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _countryError = countryError;
      _cityError = cityError;

      // A rejected credential belongs to the first step, which is off screen by
      // the time the request comes back — the message would land nowhere.
      if (emailError != null || passwordError != null) {
        _step = _RegisterStep.account;
      }
    });
  }

  /// Rebuilds only when there is actually an error to drop.
  void _clearFieldError(VoidCallback clear, String? current) {
    if (current == null) return;
    setState(clear);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Only a submission that just came back failed — not the error the login
      // screen may already have been showing.
      listenWhen: (previous, current) =>
          previous.isSubmitting &&
          !current.isSubmitting &&
          current.errorMessage != null,
      listener: _onSubmitFailed,
      builder: (context, state) {
        return PopScope(
          // Back walks the steps and only leaves the page from the first one.
          canPop: _step == _RegisterStep.account,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goTo(_RegisterStep.account);
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Create an account')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: _step.index,
                    // Going back is always allowed; going forward is earned by
                    // passing the step you are on.
                    onStepTapped: state.isSubmitting
                        ? null
                        : (index) {
                            if (index < _step.index) {
                              _goTo(_RegisterStep.values[index]);
                            }
                          },
                    onStepContinue: state.isSubmitting
                        ? null
                        : (_step.isLast ? _submit : _continue),
                    onStepCancel: _step == _RegisterStep.account
                        ? null
                        : () => _goTo(_RegisterStep.account),
                    controlsBuilder: (context, details) => _StepControls(
                      details: details,
                      isSubmitting: state.isSubmitting,
                      continueLabel: _step.isLast
                          ? 'Create account'
                          : 'Continue',
                    ),
                    steps: [
                      Step(
                        title: const Text('Account'),
                        isActive: true,
                        state: _step == _RegisterStep.account
                            ? StepState.editing
                            : StepState.complete,
                        content: _accountStep(state),
                      ),
                      Step(
                        title: const Text('Location'),
                        isActive: _step.isLast,
                        state: _step.isLast
                            ? StepState.editing
                            : StepState.indexed,
                        content: _locationStep(state),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _accountStep(AuthState state) {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _emailError,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.newUsername],
            enabled: !state.isSubmitting,
            onChanged: (_) => _clearFieldError(() {
              _emailError = null;
            }, _emailError),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText:
                  'At least ${AuthValidators.minPasswordLength} characters',
              errorText: _passwordError,
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !state.isSubmitting,
            onChanged: (_) => _clearFieldError(() {
              _passwordError = null;
            }, _passwordError),
            validator: AuthValidators.newPassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !state.isSubmitting,
            onFieldSubmitted: (_) => _continue(),
            validator: (value) =>
                AuthValidators.confirmPassword(value, _passwordController.text),
          ),
        ],
      ),
    );
  }

  Widget _locationStep(AuthState state) {
    final theme = Theme.of(context);

    return Form(
      key: _locationFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where are you based? The Lobbies tab browses this city for you, '
            'and a new lobby starts here. Both are optional — you can set them '
            'later in your profile.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Country',
              errorText: _countryError,
            ),
            textInputAction: TextInputAction.next,
            enabled: !state.isSubmitting,
            onChanged: (_) => _clearFieldError(() {
              _countryError = null;
            }, _countryError),
            validator: AuthValidators.place,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'City',
              errorText: _cityError,
            ),
            enabled: !state.isSubmitting,
            onChanged: (_) => _clearFieldError(() {
              _cityError = null;
            }, _cityError),
            onFieldSubmitted: (_) => _submit(),
            validator: AuthValidators.place,
          ),
        ],
      ),
    );
  }
}

/// The stepper's buttons, so the last step reads "Create account" and shows the
/// request in flight.
class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.details,
    required this.isSubmitting,
    required this.continueLabel,
  });

  final ControlsDetails details;
  final bool isSubmitting;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: details.onStepContinue,
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(continueLabel),
            ),
          ),
          if (details.onStepCancel != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: isSubmitting ? null : details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }
}
