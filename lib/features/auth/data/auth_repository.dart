import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

/// Talks to the auth endpoints and owns the lifetime of the session token.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class AuthRepository {
  // Private field formals: callers still pass `dio:` and `tokenStorage:`.
  const AuthRepository({required this._dio, required this._tokenStorage});

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// True when a token is on disk. Does not prove the token is still valid —
  /// [currentUser] is what confirms that against the server.
  bool get hasStoredSession => _tokenStorage.hasToken;

  Future<User> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, dynamic>{
          'username': username,
          'password': password,
          'expiresInMins': 60,
        },
      );

      final data = response.data;
      final token = data?['accessToken'] as String?;
      if (data == null || token == null || token.isEmpty) {
        throw const ApiException('The server did not return a session token.');
      }

      await _tokenStorage.writeToken(token);
      return User.fromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// Restores the session: resolves the stored token into a [User].
  Future<User> currentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty profile.');
      }
      return User.fromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<void> logout() => _tokenStorage.clearToken();
}
