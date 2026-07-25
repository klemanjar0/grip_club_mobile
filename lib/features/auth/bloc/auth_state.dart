part of 'auth_bloc.dart';

/// [unknown] means "not decided yet" — the app shows the splash screen while the
/// stored token is being validated. The router guard keys off this enum.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
    this.errorCode,
    this.fieldErrors = const {},
    this.isSubmitting = false,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(User user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({
    String? errorMessage,
    String? errorCode,
    Map<String, String> fieldErrors = const {},
  }) : this._(
         status: AuthStatus.unauthenticated,
         errorMessage: errorMessage,
         errorCode: errorCode,
         fieldErrors: fieldErrors,
       );

  /// A login or register attempt is in flight. Status stays
  /// [AuthStatus.unauthenticated] so the router does not navigate mid-request.
  const AuthState.submitting()
    : this._(status: AuthStatus.unauthenticated, isSubmitting: true);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// The API's error code for the last failure, e.g. `email_taken`. Forms use
  /// it to place an error on the right field instead of in a snackbar.
  final String? errorCode;

  /// Per-field validation errors from `validation_failed`, keyed by JSON field
  /// name (`email`, `password`).
  final Map<String, String> fieldErrors;

  final bool isSubmitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [
    status,
    user,
    errorMessage,
    errorCode,
    fieldErrors,
    isSubmitting,
  ];
}
