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
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Registering also signs the user in — there is no separate login step.
///
/// [country] and [city] are the home location the second step of the sign-up
/// asks for. They are `null` when that step was skipped.
final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.country,
    this.city,
  });

  final String email;
  final String password;
  final String? country;
  final String? city;

  @override
  List<Object?> get props => [email, password, country, city];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Revokes every session, this device included.
final class AuthLogoutAllRequested extends AuthEvent {
  const AuthLogoutAllRequested();
}

/// The profile changed elsewhere (the preferences form saved a new one).
///
/// Keeps the app-wide [User] current without a refetch — the lobby feeds read
/// their default city and time filter from it.
final class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Dispatched by [AuthInterceptor] when the server rejects the stored token.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
