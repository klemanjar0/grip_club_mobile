import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';

/// Replies with a canned payload instead of hitting the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The real shape of `POST /auth/login` on dummyjson (keys captured from a live
/// call), so the parsing below is checked against what the server actually sends.
const Map<String, dynamic> _loginResponse = <String, dynamic>{
  'accessToken': 'header.payload.signature',
  'refreshToken': 'refresh.token.value',
  'id': 1,
  'username': 'emilys',
  'email': 'emily.johnson@x.dummyjson.com',
  'firstName': 'Emily',
  'lastName': 'Johnson',
  'gender': 'female',
  'image': 'https://dummyjson.com/icon/emilys/128',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TokenStorage> emptyStorage() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return TokenStorage(await SharedPreferences.getInstance());
  }

  AuthRepository repositoryWith({
    required TokenStorage storage,
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _StubAdapter(statusCode: statusCode, body: body);
    return AuthRepository(dio: dio, tokenStorage: storage);
  }

  test('login parses the user and persists the access token', () async {
    final storage = await emptyStorage();
    final repository = repositoryWith(
      storage: storage,
      statusCode: 200,
      body: _loginResponse,
    );

    final user = await repository.login(
      username: 'emilys',
      password: 'emilyspass',
    );

    expect(user.id, 1);
    expect(user.username, 'emilys');
    expect(user.displayName, 'Emily Johnson');
    expect(user.email, 'emily.johnson@x.dummyjson.com');
    expect(user.imageUrl, 'https://dummyjson.com/icon/emilys/128');
    expect(storage.readToken(), 'header.payload.signature');
    expect(repository.hasStoredSession, isTrue);
  });

  test('login surfaces the server message and stores nothing', () async {
    final storage = await emptyStorage();
    final repository = repositoryWith(
      storage: storage,
      statusCode: 400,
      // Exactly what dummyjson returns for a wrong password.
      body: const <String, dynamic>{'message': 'Invalid credentials'},
    );

    await expectLater(
      repository.login(username: 'emilys', password: 'wrong'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Invalid credentials')
            .having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
    expect(repository.hasStoredSession, isFalse);
  });

  test('login rejects a response without a token', () async {
    final storage = await emptyStorage();
    final repository = repositoryWith(
      storage: storage,
      statusCode: 200,
      body: const <String, dynamic>{'id': 1, 'username': 'emilys'},
    );

    await expectLater(
      repository.login(username: 'emilys', password: 'emilyspass'),
      throwsA(isA<ApiException>()),
    );
    expect(repository.hasStoredSession, isFalse);
  });

  test('logout clears the stored token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TokenStorage.tokenKey: 'header.payload.signature',
    });
    final storage = TokenStorage(await SharedPreferences.getInstance());
    final repository = repositoryWith(
      storage: storage,
      statusCode: 200,
      body: _loginResponse,
    );

    expect(repository.hasStoredSession, isTrue);
    await repository.logout();
    expect(repository.hasStoredSession, isFalse);
  });
}
