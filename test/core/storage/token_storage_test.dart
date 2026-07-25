import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TokenStorage> storageWith([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return TokenStorage(await SharedPreferences.getInstance());
  }

  test('writes, reads and clears the session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final storage = TokenStorage(preferences);
    final expiresAt = DateTime.utc(2099, 1, 1);

    expect(storage.readToken(), isNull);
    expect(storage.hasToken, isFalse);

    await storage.writeSession(token: 'token-abc', expiresAt: expiresAt);

    expect(storage.readToken(), 'token-abc');
    expect(storage.readExpiresAt(), expiresAt);
    expect(storage.hasToken, isTrue);
    // Stored under the documented keys, so an existing install keeps working if
    // this class is ever refactored.
    expect(preferences.getString(TokenStorage.tokenKey), 'token-abc');
    expect(
      preferences.getString(TokenStorage.expiresAtKey),
      '2099-01-01T00:00:00.000Z',
    );

    await storage.clearToken();

    expect(storage.readToken(), isNull);
    expect(storage.readExpiresAt(), isNull);
    expect(storage.hasToken, isFalse);
  });

  test('a past expiry means there is no usable session', () async {
    final storage = await storageWith(<String, Object>{
      TokenStorage.tokenKey: 'token-abc',
      TokenStorage.expiresAtKey: '2020-01-01T00:00:00.000Z',
    });

    // The token is still readable — the interceptor may still attach it — but
    // the app must not treat it as a session worth restoring.
    expect(storage.readToken(), 'token-abc');
    expect(storage.hasToken, isFalse);
  });

  test('an absent or unparseable expiry leaves the server to decide', () async {
    expect(
      (await storageWith(<String, Object>{
        TokenStorage.tokenKey: 'token-abc',
      })).hasToken,
      isTrue,
    );
    expect(
      (await storageWith(<String, Object>{
        TokenStorage.tokenKey: 'token-abc',
        TokenStorage.expiresAtKey: 'not-a-date',
      })).hasToken,
      isTrue,
    );
  });

  test('writing without an expiry drops a stale one', () async {
    final storage = await storageWith(<String, Object>{
      TokenStorage.tokenKey: 'old-token',
      TokenStorage.expiresAtKey: '2020-01-01T00:00:00.000Z',
    });

    await storage.writeSession(token: 'new-token', expiresAt: null);

    expect(storage.readExpiresAt(), isNull);
    expect(storage.hasToken, isTrue);
  });
}
