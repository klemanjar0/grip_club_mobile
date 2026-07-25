import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Single source of truth for session state. Registered as a singleton because
/// the router guard listens to it for the whole life of the app.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._repository}) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    if (!_repository.hasStoredSession) {
      emit(const AuthState.unauthenticated());
      return;
    }

    try {
      emit(AuthState.authenticated(await _repository.currentUser()));
    } on ApiException catch (exception) {
      // A 401 here just means the stored token expired — not worth an error
      // message. Anything else (offline, server down) is worth reporting.
      await _repository.logout();
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
  ) async {
    emit(const AuthState.submitting());

    try {
      final user = await _repository.login(
        username: event.username,
        password: event.password,
      );
      emit(AuthState.authenticated(user));
    } on ApiException catch (exception) {
      emit(AuthState.unauthenticated(errorMessage: exception.message));
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
    // The interceptor already cleared the token before dispatching this.
    emit(
      const AuthState.unauthenticated(
        errorMessage: 'Your session has expired. Please sign in again.',
      ),
    );
  }
}
