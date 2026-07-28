part of 'auth_bloc.dart';

/// [unknown] means "not decided yet" — the app shows the splash screen while the
/// stored token is being validated. [unavailable] means the backend could not be
/// reached at startup, so there is nothing to decide *with*. The router guard
/// keys off this enum.
enum AuthStatus { unknown, authenticated, unauthenticated, unavailable }

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

  /// The startup check could not reach the server. [errorMessage] is the
  /// transport-level reason ("No internet connection."), shown under the
  /// maintenance copy so an offline user is not told the servers are down.
  const AuthState.unavailable({String? errorMessage})
    : this._(status: AuthStatus.unavailable, errorMessage: errorMessage);

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
