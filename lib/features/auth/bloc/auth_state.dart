part of 'auth_bloc.dart';

/// [unknown] means "not decided yet" — the app shows the splash screen while the
/// stored token is being validated. The router guard keys off this enum.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
    this.isSubmitting = false,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(User user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({String? errorMessage})
    : this._(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  /// A login attempt is in flight. Status stays [AuthStatus.unauthenticated] so
  /// the router does not navigate mid-request.
  const AuthState.submitting()
    : this._(status: AuthStatus.unauthenticated, isSubmitting: true);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isSubmitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [status, user, errorMessage, isSubmitting];
}
