import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/storage/token_storage.dart';

/// Attaches the stored session token to every outgoing request and reacts to a
/// rejected token.
///
/// [onUnauthorized] is a callback rather than a direct reference to the auth
/// bloc so the network layer stays free of any dependency on feature code.
class AuthInterceptor extends Interceptor {
  // Private field formal: callers still pass `tokenStorage:`.
  AuthInterceptor({
    required this._tokenStorage,
    required this.onUnauthorized,
  });

  static const String authorizationHeader = 'Authorization';

  final TokenStorage _tokenStorage;
  final void Function() onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStorage.readToken();
    // An explicit header on the request wins, so a caller can opt out.
    if (token != null && !options.headers.containsKey(authorizationHeader)) {
      options.headers[authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // The token is no longer accepted: drop it and let the app react (the
      // router guard sends the user back to the login screen).
      await _tokenStorage.clearToken();
      onUnauthorized();
    }
    handler.next(err);
  }
}
