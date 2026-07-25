import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/core/network/auth_interceptor.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';

/// Captures the outgoing request and replies with a canned status code, so the
/// interceptor can be exercised without a server.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({this.statusCode = 200});

  final int statusCode;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TokenStorage> storageWith({String? token}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TokenStorage.tokenKey: ?token,
    });
    return TokenStorage(await SharedPreferences.getInstance());
  }

  Dio dioWith({
    required TokenStorage storage,
    required _CapturingAdapter adapter,
    void Function()? onUnauthorized,
  }) {
    return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          onUnauthorized: onUnauthorized ?? () {},
        ),
      );
  }

  test('adds a Bearer header when a token is stored', () async {
    final adapter = _CapturingAdapter();
    final dio = dioWith(
      storage: await storageWith(token: 'token-abc'),
      adapter: adapter,
    );

    await dio.get<Map<String, dynamic>>('/auth/me');

    expect(
      adapter.lastRequest?.headers[AuthInterceptor.authorizationHeader],
      'Bearer token-abc',
    );
  });

  test('sends no Authorization header when there is no token', () async {
    final adapter = _CapturingAdapter();
    final dio = dioWith(storage: await storageWith(), adapter: adapter);

    await dio.get<Map<String, dynamic>>('/auth/me');

    expect(
      adapter.lastRequest?.headers.containsKey(
        AuthInterceptor.authorizationHeader,
      ),
      isFalse,
    );
  });

  test('clears the token and notifies on a 401', () async {
    final storage = await storageWith(token: 'token-abc');
    var unauthorizedCalls = 0;
    final dio = dioWith(
      storage: storage,
      adapter: _CapturingAdapter(statusCode: 401),
      onUnauthorized: () => unauthorizedCalls++,
    );

    await expectLater(
      dio.get<Map<String, dynamic>>('/auth/me'),
      throwsA(isA<DioException>()),
    );

    expect(storage.readToken(), isNull);
    expect(unauthorizedCalls, 1);
  });
}
