import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';

/// Dev credentials for the dummyjson API the dev flavor points at.
const String _devUsername = 'emilys';
const String _devPassword = 'emilyspass';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  // Prefilled in dev so the sample API can be exercised in one tap.
  final _usernameController = TextEditingController(
    text: AppConfig.isDev ? _devUsername : '',
  );
  final _passwordController = TextEditingController(
    text: AppConfig.isDev ? _devPassword : '',
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current.errorMessage != null &&
              previous.errorMessage != current.errorMessage,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          },
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
                        Text(
                          AppConfig.appName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enabled: !state.isSubmitting,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter your username'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                          enabled: !state.isSubmitting,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Enter your password'
                              : null,
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
                              : const Text('Sign in'),
                        ),
                        if (AppConfig.isDev) ...[
                          const SizedBox(height: 24),
                          Text(
                            'dev flavor · ${AppConfig.apiBaseUrl}\n'
                            '$_devUsername / $_devPassword',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
}
