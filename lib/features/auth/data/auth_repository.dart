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

  /// True when an unexpired token is on disk. Does not prove the server still
  /// accepts it — [currentUser] is what confirms that.
  bool get hasStoredSession => _tokenStorage.hasToken;

  Future<User> login({required String email, required String password}) =>
      _authenticate('/auth/login', <String, dynamic>{
        'email': email,
        'password': password,
      });

  /// Registering signs you in: the response already carries a live session.
  Future<User> register({required String email, required String password}) =>
      _authenticate('/auth/register', <String, dynamic>{
        'email': email,
        'password': password,
      });

  /// Restores the session: resolves the stored token into a [User].
  Future<User> currentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/me');
      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty profile.');
      }
      return User.fromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// Revokes the session server-side, then drops the local token.
  ///
  /// A failed call is swallowed on purpose: signing out must never be blocked
  /// by the network, and an unusable token is better forgotten either way.
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Ignored — the local clear below is what the user asked for.
    } finally {
      await _tokenStorage.clearToken();
    }
  }

  /// Shared by login and register: both return `CredentialsResponse`.
  ///
  /// That payload's nested user is only `{id, email, created_at}`, so the token
  /// is persisted and the full profile is then fetched from `/me`. One extra
  /// round trip buys a single [User] shape everywhere in the app.
  Future<User> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);

      final data = response.data;
      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException('The server did not return a session token.');
      }

      await _tokenStorage.writeSession(
        token: token,
        expiresAt: DateTime.tryParse(data?['expires_at'] as String? ?? ''),
      );
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }

    return currentUser();
  }
}
