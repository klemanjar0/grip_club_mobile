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
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // Started before the work, awaited after it, so the check and the floor
    // overlap instead of adding up.
    final splashFloor = Future<void>.delayed(_minimumSplashDuration);

    if (!_repository.hasStoredSession) {
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
      // A 401 just means the stored token expired: the interceptor has already
      // dropped it, and landing on the login screen says everything. Any other
      // failure (offline, server down) keeps the token — it may still be good
      // on the next launch — and is worth reporting.
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
    () => _repository.register(email: event.email, password: event.password),
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
