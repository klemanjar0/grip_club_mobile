import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = User(
  id: 1,
  username: 'emilys',
  email: 'emily.johnson@x.dummyjson.com',
  firstName: 'Emily',
  lastName: 'Johnson',
);

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(repository.logout).thenAnswer((_) async {});
  });

  group('AuthStarted', () {
    blocTest<AuthBloc, AuthState>(
      'is unauthenticated when no token is stored',
      setUp: () => when(() => repository.hasStoredSession).thenReturn(false),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => const <AuthState>[AuthState.unauthenticated()],
      verify: (_) => verifyNever(repository.currentUser),
    );

    blocTest<AuthBloc, AuthState>(
      'restores the session when the stored token is still valid',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenAnswer((_) async => _user);
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => const <AuthState>[AuthState.authenticated(_user)],
    );

    blocTest<AuthBloc, AuthState>(
      'drops an expired token without surfacing an error message',
      setUp: () {
        when(() => repository.hasStoredSession).thenReturn(true);
        when(repository.currentUser).thenThrow(
          const ApiException('Invalid/Expired Token!', statusCode: 401),
        );
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => const <AuthState>[AuthState.unauthenticated()],
      verify: (_) => verify(repository.logout).called(1),
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits submitting then authenticated on success',
      setUp: () => when(
        () => repository.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(username: 'emilys', password: 'emilyspass'),
      ),
      expect: () => const <AuthState>[
        AuthState.submitting(),
        AuthState.authenticated(_user),
      ],
      verify: (_) => verify(
        () => repository.login(username: 'emilys', password: 'emilyspass'),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'reports the failure message and stays unauthenticated',
      setUp: () => when(
        () => repository.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ApiException('Invalid credentials', statusCode: 400),
      ),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(username: 'emilys', password: 'wrong'),
      ),
      expect: () => const <AuthState>[
        AuthState.submitting(),
        AuthState.unauthenticated(errorMessage: 'Invalid credentials'),
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

  blocTest<AuthBloc, AuthState>(
    'AuthSessionExpired asks the user to sign in again',
    build: () => AuthBloc(repository: repository),
    act: (bloc) => bloc.add(const AuthSessionExpired()),
    expect: () => const <AuthState>[
      AuthState.unauthenticated(
        errorMessage: 'Your session has expired. Please sign in again.',
      ),
    ],
  );
}
