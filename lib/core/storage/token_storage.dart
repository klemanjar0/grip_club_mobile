import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session token in `SharedPreferences`.
///
/// Takes an already-loaded [SharedPreferences] instance (resolved once in
/// `configureDependencies`) so reads are synchronous — [AuthInterceptor] needs
/// the token inside `onRequest` without awaiting.
class TokenStorage {
  const TokenStorage(this._preferences);

  static const String tokenKey = 'session_token';

  final SharedPreferences _preferences;

  String? readToken() => _preferences.getString(tokenKey);

  bool get hasToken => (readToken()?.isNotEmpty ?? false);

  Future<void> writeToken(String token) =>
      _preferences.setString(tokenKey, token);

  Future<void> clearToken() => _preferences.remove(tokenKey);
}
