part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at startup: restores a stored session, if any.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.username, required this.password});

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Dispatched by [AuthInterceptor] when the server rejects the stored token.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
