import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// How long the splash screen stays up at the very least. Without a floor the
/// session check against a local API finishes in a few milliseconds and the
/// splash reads as a flicker.
const Duration _minimumSplashDuration = Duration(milliseconds: 600);

/// Single source of truth for session state. Registered as a singleton because
/// the router guard listens to it for the whole life of the app.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._repository}) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLogoutAllRequested>(_onLogoutAllRequested);
    on<AuthUserUpdated>(_onUserUpdated);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  /// Also the retry path: the maintenance screen re-dispatches [AuthStarted],
  /// and going back through [AuthStatus.unknown] is what returns the router to
  /// the splash screen so the whole flow restarts from the top.
  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    if (state.status != AuthStatus.unknown) emit(const AuthState.unknown());

    // Started before the work, awaited after it, so the check and the floor
    // overlap instead of adding up.
    final splashFloor = Future<void>.delayed(_minimumSplashDuration);

    if (!_repository.hasStoredSession) {
      // Nothing to restore, but the launch still has to notice a dead backend —
      // otherwise a fresh install meets a login form that cannot possibly work.
      try {
        await _repository.ensureServerReachable();
      } on ApiException catch (exception) {
        await splashFloor;
        emit(AuthState.unavailable(errorMessage: exception.message));
        return;
      }

      await splashFloor;
      emit(const AuthState.unauthenticated());
      return;
    }

    try {
      final user = await _repository.currentUser();
      await splashFloor;
      emit(AuthState.authenticated(user));
    } on ApiException catch (exception) {
      await splashFloor;

      // Nothing answered, or a 5xx did: the app cannot work at all, so it says
      // so on its own screen instead of dumping the user on a login form.
      if (exception.isServerUnavailable) {
        emit(AuthState.unavailable(errorMessage: exception.message));
        return;
      }

      // A 401 just means the stored token expired: the interceptor has already
      // dropped it, and landing on the login screen says everything. Any other
      // 4xx keeps the token — it may still be good on the next launch — and is
      // worth reporting.
      emit(
        AuthState.unauthenticated(
          errorMessage: exception.isUnauthorized ? null : exception.message,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) => _submit(
    emit,
    () => _repository.login(email: event.email, password: event.password),
  );

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) => _submit(
    emit,
    () => _repository.register(
      email: event.email,
      password: event.password,
      country: event.country,
      city: event.city,
    ),
  );

  /// Login and register differ only in the call they make: both show a spinner,
  /// both end in an authenticated user or a form-level failure.
  Future<void> _submit(
    Emitter<AuthState> emit,
    Future<User> Function() request,
  ) async {
    emit(const AuthState.submitting());

    try {
      emit(AuthState.authenticated(await request()));
    } on ApiException catch (exception) {
      emit(
        AuthState.unauthenticated(
          errorMessage: exception.message,
          errorCode: exception.code,
          fieldErrors: exception.fieldErrors,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthState.unauthenticated());
  }

  /// Signing out everywhere ends this session too, so it lands on the login
  /// screen exactly like [_onLogoutRequested]. A failed call still signs this
  /// device out — the repository has already dropped the local token.
  Future<void> _onLogoutAllRequested(
    AuthLogoutAllRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.logoutAll();
      emit(const AuthState.unauthenticated());
    } on ApiException catch (exception) {
      emit(AuthState.unauthenticated(errorMessage: exception.message));
    }
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    // Ignored when signed out: a stale profile must never resurrect a session.
    if (state.status != AuthStatus.authenticated) return;

    emit(AuthState.authenticated(event.user));
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    // The interceptor fires this for any rejected token, including the one the
    // startup restore is in the middle of checking. Only a session that was
    // live and then died is worth a message; `_onStarted` reports its own.
    if (state.status != AuthStatus.authenticated) return;

    emit(
      const AuthState.unauthenticated(
        errorMessage: 'Your session has expired. Please sign in again.',
      ),
    );
  }
}
