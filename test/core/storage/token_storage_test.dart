import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grip_club_mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes, reads and clears the session token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final storage = TokenStorage(preferences);

    expect(storage.readToken(), isNull);
    expect(storage.hasToken, isFalse);

    await storage.writeToken('token-abc');

    expect(storage.readToken(), 'token-abc');
    expect(storage.hasToken, isTrue);
    // Stored under the documented key, so an existing install keeps working if
    // this class is ever refactored.
    expect(preferences.getString(TokenStorage.tokenKey), 'token-abc');

    await storage.clearToken();

    expect(storage.readToken(), isNull);
    expect(storage.hasToken, isFalse);
  });
}
