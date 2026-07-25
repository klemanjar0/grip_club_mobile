/// The build environment. Selected by the `--flavor` flag natively and by the
/// `FLAVOR` key of the env JSON on the Dart side; the two are kept in sync by
/// the assertion in `bootstrap()`.
enum Flavor { dev, prod }

/// Compile-time configuration, supplied by `--dart-define-from-file=env/<flavor>.json`.
///
/// Every value must be a `static const` because `String.fromEnvironment` and
/// friends are only usable in a const context. Adding a new key means adding it
/// to *all* files in `env/` as well as here — a missing key silently falls back
/// to the default value.
///
/// Note that `--dart-define-from-file` only supports scalar JSON values
/// (string / number / bool); nested objects and arrays are not read.
abstract final class AppConfig {
  static const String _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// Human-readable app name, also used as the `MaterialApp` title.
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Grip Club',
  );

  /// Base URL for every request made through the shared [Dio] instance.
  /// Deliberately has no default so a missing env file fails loudly at startup.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const int connectTimeoutMs = int.fromEnvironment(
    'API_CONNECT_TIMEOUT_MS',
    defaultValue: 15000,
  );

  /// Enables Dio request/response logging. Should stay off in prod.
  static const bool enableHttpLogging = bool.fromEnvironment(
    'ENABLE_HTTP_LOGGING',
  );

  static Flavor get flavor => Flavor.values.firstWhere(
    (flavor) => flavor.name == _flavorName,
    orElse: () => Flavor.dev,
  );

  static bool get isDev => flavor == Flavor.dev;

  static Duration get connectTimeout =>
      Duration(milliseconds: connectTimeoutMs);
}
