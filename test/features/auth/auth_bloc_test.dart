import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _user = User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'rider',
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

/// `AuthStarted` holds the splash for a minimum duration, so its tests need to
/// outlast that floor rather than settle immediately.
const _pastSplashFloor = Duration(milliseconds: 900);

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(repository.logout).thenAnswer((_) async {});
    when(repository.ensureServerReachable).thenAnswer((_) async {});
  });

  group('AuthStarted', () {
    blocTest<AuthBloc, AuthState>(
      'is unauthenticated when no usable token is stored',
      setUp: () => when(() => repository.hasStoredSession).thenReturn(false),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[AuthState.unauthenticated()],
      // An expired or absent token must not cost a doomed session restore —
      // only the reachability probe, which is what catches a dead backend.
      verify: (_) => verifyNever(repository.currentUser),
    );

    blocTest<AuthBloc, AuthState>(
      'is unavailable when the server does not answer the probe',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(false);
        when(repository.ensureServerReachable).thenThrow(
          const ApiException(
            'No internet connection.',
            isTransportFailure: true,
          ),
        );
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[
        AuthState.unavailable(errorMessage: 'No internet connection.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'is unavailable when restoring the session times out',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenThrow(
          const ApiException(
            'The server took too long to respond. Please try again.',
            isTransportFailure: true,
          ),
        );
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[
        AuthState.unavailable(
          errorMessage:
              'The server took too long to respond. Please try again.',
        ),
      ],
      // The token is untouched: the server never said it was bad.
      verify: (_) => verifyNever(repository.logout),
    );

    blocTest<AuthBloc, AuthState>(
      'is unavailable when the session check comes back 5xx',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(
          repository.currentUser,
        ).thenThrow(const ApiException('Under maintenance.', statusCode: 503));
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[
        AuthState.unavailable(errorMessage: 'Under maintenance.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'retrying from the maintenance screen goes back through unknown',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenAnswer((_) async => _user);
      },
      // Starts where a failed launch left the app.
      seed: () => const AuthState.unavailable(errorMessage: 'Offline.'),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      // `unknown` is what sends the router back to the splash screen, so the
      // whole launch flow restarts rather than resuming under the error.
      expect: () => <AuthState>[
        const AuthState.unknown(),
        AuthState.authenticated(_user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'restores the session when the stored token is still valid',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenAnswer((_) async => _user);
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => <AuthState>[AuthState.authenticated(_user)],
    );

    blocTest<AuthBloc, AuthState>(
      'a rejected token lands on login with no error message',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenThrow(
          const ApiException(
            'Unauthorized',
            statusCode: 401,
            code: 'unauthorized',
          ),
        );
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'reports a non-401 client failure and keeps the token for the next launch',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        // A 4xx is this client asking wrongly, not an outage: it belongs on the
        // login screen with its message, not on the maintenance screen.
        when(repository.currentUser).thenThrow(
          const ApiException('Your account is suspended.', statusCode: 403),
        );
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: _pastSplashFloor,
      expect: () => const <AuthState>[
        AuthState.unauthenticated(errorMessage: 'Your account is suspended.'),
      ],
      verify: (_) => verifyNever(repository.logout),
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits submitting then authenticated on success',
      setUp: () => when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'rider@example.com',
          password: 'correct-horse',
        ),
      ),
      expect: () => <AuthState>[
        const AuthState.submitting(),
        AuthState.authenticated(_user),
      ],
      verify: (_) => verify(
        () => repository.login(
          email: 'rider@example.com',
          password: 'correct-horse',
        ),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'reports the failure message and stays unauthenticated',
      setUp: () =>
          when(
            () => repository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            const ApiException(
              'Email or password is wrong.',
              statusCode: 401,
              code: 'invalid_credentials',
            ),
          ),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'rider@example.com', password: 'wrong'),
      ),
      expect: () => const <AuthState>[
        AuthState.submitting(),
        AuthState.unauthenticated(
          errorMessage: 'Email or password is wrong.',
          errorCode: 'invalid_credentials',
        ),
      ],
    );
  });

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'signs the new user straight in',
      setUp: () => when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'rider@example.com',
          password: 'correct-horse',
        ),
      ),
      expect: () => <AuthState>[
        const AuthState.submitting(),
        AuthState.authenticated(_user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'carries the home location from the second step through',
      setUp: () => when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          country: any(named: 'country'),
          city: any(named: 'city'),
        ),
      ).thenAnswer((_) async => _user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'rider@example.com',
          password: 'correct-horse',
          country: 'Ukraine',
          city: 'Kyiv',
        ),
      ),
      expect: () => <AuthState>[
        const AuthState.submitting(),
        AuthState.authenticated(_user),
      ],
      verify: (_) => verify(
        () => repository.register(
          email: 'rider@example.com',
          password: 'correct-horse',
          country: 'Ukraine',
          city: 'Kyiv',
        ),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'carries the error code through so the form can place it',
      setUp: () =>
          when(
            () => repository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            const ApiException(
              'That email is already registered.',
              statusCode: 409,
              code: 'email_taken',
            ),
          ),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'rider@example.com',
          password: 'correct-horse',
        ),
      ),
      expect: () => const <AuthState>[
        AuthState.submitting(),
        AuthState.unauthenticated(
          errorMessage: 'That email is already registered.',
          errorCode: 'email_taken',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'carries validation details through as field errors',
      setUp: () =>
          when(
            () => repository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            const ApiException(
              'The request payload is invalid.',
              statusCode: 400,
              code: 'validation_failed',
              fieldErrors: <String, String>{
                'password': 'must be at least 8 characters long',
              },
            ),
          ),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'rider@example.com',
          password: 'short',
        ),
      ),
      expect: () => const <AuthState>[
        AuthState.submitting(),
        AuthState.unauthenticated(
          errorMessage: 'The request payload is invalid.',
          errorCode: 'validation_failed',
          fieldErrors: <String, String>{
            'password': 'must be at least 8 characters long',
          },
        ),
      ],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'AuthLogoutRequested clears the session',
    build: () => AuthBloc(repository: repository),
    act: (bloc) => bloc.add(const AuthLogoutRequested()),
    expect: () => const <AuthState>[AuthState.unauthenticated()],
    verify: (_) => verify(repository.logout).called(1),
  );

  group('AuthSessionExpired', () {
    blocTest<AuthBloc, AuthState>(
      'asks the user to sign in again when a live session dies',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenAnswer((_) async => _user);
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) async {
        bloc.add(const AuthStarted());
        await Future<void>.delayed(_pastSplashFloor);
        bloc.add(const AuthSessionExpired());
      },
      expect: () => <AuthState>[
        AuthState.authenticated(_user),
        const AuthState.unauthenticated(
          errorMessage: 'Your session has expired. Please sign in again.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'stays quiet when the interceptor fires during the startup check',
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthSessionExpired()),
      // Status is still `unknown`: `AuthStarted` reports its own outcome, and
      // an expired token at launch is not worth a message.
      expect: () => const <AuthState>[],
    );
  });
}
