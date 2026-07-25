import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';

class _Stub {
  const _Stub(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Replies with a canned payload per path instead of hitting the network.
///
/// Keyed by path because logging in makes two calls: the credentials endpoint
/// and then `GET /me`.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._responses);

  final Map<String, _Stub> _responses;

  /// Every request that was made, in order — lets tests assert on the payload.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final stub =
        _responses[options.path] ??
        const _Stub(404, <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'No stub registered for this path.',
          },
        });

    return ResponseBody.fromString(
      jsonEncode(stub.body),
      stub.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// `CredentialsResponse` — the shape returned by register and login.
const Map<String, dynamic> _credentials = <String, dynamic>{
  'token': 'opaque-session-token',
  'expires_at': '2026-09-23T18:30:00Z',
  'user': <String, dynamic>{
    'id': '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
    'email': 'rider@example.com',
    'created_at': '2026-08-24T18:30:00Z',
  },
};

/// `UserResponse` — the full profile, only available from `GET /me`.
const Map<String, dynamic> _profile = <String, dynamic>{
  'id': '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  'email': 'rider@example.com',
  'display_name': 'rider',
  'locale': 'en',
  'timezone': 'Europe/Kyiv',
  'city': 'Kyiv',
  'time_filter': 'week',
  'created_at': '2026-08-24T18:30:00Z',
};

Map<String, dynamic> _errorBody(
  String code,
  String message, {
  Map<String, String>? details,
}) => <String, dynamic>{
  'error': <String, dynamic>{
    'code': code,
    'message': message,
    if (details case final Map<String, String> value) 'details': value,
    'request_id': 'test-request-id',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubAdapter adapter;

  Future<TokenStorage> storageWith([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return TokenStorage(await SharedPreferences.getInstance());
  }

  AuthRepository repositoryWith({
    required TokenStorage storage,
    required Map<String, _Stub> responses,
  }) {
    adapter = _StubAdapter(responses);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    return AuthRepository(dio: dio, tokenStorage: storage);
  }

  group('login', () {
    test(
      'persists the token and expiry, then returns the /me profile',
      () async {
        final storage = await storageWith();
        final repository = repositoryWith(
          storage: storage,
          responses: <String, _Stub>{
            '/auth/login': const _Stub(200, _credentials),
            '/me': const _Stub(200, _profile),
          },
        );

        final user = await repository.login(
          email: 'rider@example.com',
          password: 'correct-horse',
        );

        // The profile comes from /me, not from the credentials payload — only
        // /me carries display_name, city and time_filter.
        expect(user.id, '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11');
        expect(user.email, 'rider@example.com');
        expect(user.displayName, 'rider');
        expect(user.timezone, 'Europe/Kyiv');
        expect(user.city, 'Kyiv');
        expect(user.timeFilter, 'week');

        expect(storage.readToken(), 'opaque-session-token');
        expect(storage.readExpiresAt(), DateTime.utc(2026, 9, 23, 18, 30));
        expect(repository.hasStoredSession, isTrue);

        expect(adapter.requests.map((r) => r.path), ['/auth/login', '/me']);
        expect(adapter.requests.first.data, <String, dynamic>{
          'email': 'rider@example.com',
          'password': 'correct-horse',
        });
      },
    );

    test('maps invalid_credentials onto the error code', () async {
      final storage = await storageWith();
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/login': _Stub(
            401,
            _errorBody('invalid_credentials', 'Email or password is wrong.'),
          ),
        },
      );

      await expectLater(
        repository.login(email: 'rider@example.com', password: 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having(
                (e) => e.message,
                'message',
                'Email or password is wrong.',
              )
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
      expect(repository.hasStoredSession, isFalse);
    });

    test('rejects a response without a token', () async {
      final storage = await storageWith();
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/login': const _Stub(200, <String, dynamic>{
            'expires_at': '2026-09-23T18:30:00Z',
          }),
        },
      );

      await expectLater(
        repository.login(email: 'rider@example.com', password: 'secret12'),
        throwsA(isA<ApiException>()),
      );
      expect(repository.hasStoredSession, isFalse);
    });
  });

  group('register', () {
    test('signs the user in from the 201 response', () async {
      final storage = await storageWith();
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/register': const _Stub(201, _credentials),
          '/me': const _Stub(200, _profile),
        },
      );

      final user = await repository.register(
        email: 'rider@example.com',
        password: 'correct-horse',
      );

      expect(user.email, 'rider@example.com');
      expect(storage.readToken(), 'opaque-session-token');
      expect(adapter.requests.map((r) => r.path), ['/auth/register', '/me']);
    });

    test('surfaces email_taken', () async {
      final storage = await storageWith();
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/register': _Stub(
            409,
            _errorBody('email_taken', 'That email is already registered.'),
          ),
        },
      );

      await expectLater(
        repository.register(email: 'rider@example.com', password: 'secret12'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isEmailTaken, 'isEmailTaken', isTrue)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('surfaces validation_failed details per field', () async {
      final storage = await storageWith();
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/register': _Stub(
            400,
            _errorBody(
              'validation_failed',
              'The request payload is invalid.',
              details: <String, String>{
                'email': 'must be a valid email address',
                'password': 'must be at least 8 characters long',
              },
            ),
          ),
        },
      );

      await expectLater(
        repository.register(email: 'nope', password: 'short'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'validation_failed')
              .having((e) => e.fieldErrors, 'fieldErrors', <String, String>{
                'email': 'must be a valid email address',
                'password': 'must be at least 8 characters long',
              }),
        ),
      );
    });
  });

  group('logout', () {
    test('revokes the session server-side and clears the token', () async {
      final storage = await storageWith(<String, Object>{
        TokenStorage.tokenKey: 'opaque-session-token',
      });
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/logout': const _Stub(204, <String, dynamic>{}),
        },
      );

      expect(repository.hasStoredSession, isTrue);
      await repository.logout();

      expect(adapter.requests.single.path, '/auth/logout');
      expect(repository.hasStoredSession, isFalse);
    });

    test('still clears the token when the revoke call fails', () async {
      final storage = await storageWith(<String, Object>{
        TokenStorage.tokenKey: 'opaque-session-token',
        TokenStorage.expiresAtKey: '2099-01-01T00:00:00Z',
      });
      final repository = repositoryWith(
        storage: storage,
        responses: <String, _Stub>{
          '/auth/logout': _Stub(
            500,
            _errorBody('internal_error', 'Something went wrong.'),
          ),
        },
      );

      await repository.logout();

      expect(storage.readToken(), isNull);
      expect(storage.readExpiresAt(), isNull);
    });
  });
}
