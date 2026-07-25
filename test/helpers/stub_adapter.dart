import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned response.
class Stub {
  const Stub(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Replies with a canned payload per path instead of hitting the network.
///
/// The same shape `auth_repository_test.dart` uses, lifted out because several
/// repositories now need it.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this._responses);

  final Map<String, Stub> _responses;

  /// Every request that was made, in order — lets tests assert on the payload
  /// and the query parameters.
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
        const Stub(404, <String, dynamic>{
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

/// A [Dio] wired to [adapter], with the same base URL shape the app uses
/// (`/api/v1` already included, so repositories pass bare paths).
Dio dioWith(StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;

/// The API's error envelope.
Map<String, dynamic> errorBody(
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
