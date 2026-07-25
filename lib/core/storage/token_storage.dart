import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session token and its expiry in `SharedPreferences`.
///
/// Takes an already-loaded [SharedPreferences] instance (resolved once in
/// `configureDependencies`) so reads are synchronous — [AuthInterceptor] needs
/// the token inside `onRequest` without awaiting.
class TokenStorage {
  const TokenStorage(this._preferences);

  static const String tokenKey = 'session_token';
  static const String expiresAtKey = 'session_expires_at';

  final SharedPreferences _preferences;

  String? readToken() => _preferences.getString(tokenKey);

  /// Absolute expiry as reported by the server at login. `null` when unknown —
  /// older installs, or a server that stopped sending it.
  DateTime? readExpiresAt() {
    final raw = _preferences.getString(expiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when there is a token that has not visibly expired.
  ///
  /// An unparseable or absent expiry counts as "might still be good" — the
  /// server is the real authority, and a 401 will sort it out.
  bool get hasToken {
    if (readToken()?.isNotEmpty != true) return false;

    final expiresAt = readExpiresAt();
    return expiresAt == null || expiresAt.isAfter(DateTime.now());
  }

  Future<void> writeSession({
    required String token,
    required DateTime? expiresAt,
  }) async {
    await _preferences.setString(tokenKey, token);

    if (expiresAt == null) {
      await _preferences.remove(expiresAtKey);
    } else {
      await _preferences.setString(
        expiresAtKey,
        expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> clearToken() async {
    await _preferences.remove(tokenKey);
    await _preferences.remove(expiresAtKey);
  }
}
