/// Form rules mirroring the auth endpoints, so the obvious rejections never
/// cost a round trip. The server validates all of this again — these limits
/// come straight from `POST /auth/register` in the API reference.
abstract final class AuthValidators {
  static const int maxEmailLength = 254;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxPlaceLength = 120;

  // Deliberately loose: the server owns the real definition, and an overly
  // clever regex only rejects addresses that actually work.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Enter your email';
    if (email.length > maxEmailLength) {
      return 'Email must be $maxEmailLength characters or fewer';
    }
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';

    return null;
  }

  /// Sign-in only checks for a value: login has no minimum length, so that the
  /// stored password's length is never leaked by a client-side rule.
  static String? presentPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  /// Sign-up enforces the documented 8–128 range.
  static String? newPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) return 'Choose a password';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (password.length > maxPasswordLength) {
      return 'Use at most $maxPasswordLength characters';
    }

    return null;
  }

  static String? confirmPassword(String? value, String password) =>
      value == password ? null : 'Passwords do not match';

  /// A home country or city. Optional everywhere it is asked for — both at
  /// sign-up and on the profile — so only the length is enforced.
  static String? place(String? value) =>
      (value ?? '').trim().length > maxPlaceLength
      ? 'Keep it under $maxPlaceLength characters'
      : null;
}
