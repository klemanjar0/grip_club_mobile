# Grip Club Mobile

Flutter app scaffold: **go_router** for routing (with an auth guard), **flutter_bloc** for state,
**dio** for HTTP, **shared_preferences** for the session token, and **dev / prod flavors** configured
from JSON env files.

Requires Flutter 3.44+ (Dart 3.12+).

## Flavors

| Flavor | Android applicationId     | iOS bundleId              | Display name    | Env file        |
| ------ | ------------------------- | ------------------------- | --------------- | --------------- |
| `dev`  | `com.gripclub.mobile.dev` | `com.gripclub.mobile.dev` | `Grip Club Dev` | `env/dev.json`  |
| `prod` | `com.gripclub.mobile`     | `com.gripclub.mobile`     | `Grip Club`     | `env/prod.json` |

Both flavors can be installed side by side. Flavors are the *environment* and are independent of the
build mode, so `--flavor dev --release` is a valid combination.

Every run needs three things that must agree: the native flavor (`--flavor`), the Dart entrypoint
(`-t`) and the env file (`--dart-define-from-file`). A mismatch between the entrypoint and the env
file is caught at startup by `bootstrap()` and shown as a configuration error screen instead of
silently pointing a prod build at the dev API.

The [`Makefile`](Makefile) wraps all of it — run `make` for the full list:

```bash
make run-dev                     # dev flavor, debug
make run-dev DEVICE=<device-id>  # pick a device (make devices to list them)
make run-prod-release            # prod flavor, release
make verify                      # analyze + test

make apk-dev                     # dev APK (debug)
make apk-prod                    # prod APK (release)
make bundle-prod                 # prod App Bundle for Play
make ios-dev / make ios-prod     # unsigned iOS builds
make ipa-prod                    # signed IPA for distribution
```

The equivalent raw commands, if you prefer them:

```bash
# dev, debug
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json

# prod, release
flutter run --flavor prod --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json

# builds
flutter build apk       --flavor prod --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json
flutter build appbundle --flavor prod --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json
flutter build ios       --flavor prod --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json
```

Ready-made run configurations exist for both IDEs: `.vscode/launch.json` (VS Code) and `.run/*.run.xml`
(Android Studio / IntelliJ / WebStorm).

### Env variables

`--dart-define-from-file` only reads **scalar** JSON values (string / number / bool) — nested objects
and arrays are ignored. Adding a key means touching three places: `env/dev.json`, `env/prod.json`, and
a matching `static const … .fromEnvironment` in [`lib/app/config/app_config.dart`](lib/app/config/app_config.dart).
A key that is missing from an env file silently falls back to its default.

| Key                      | Type   | Purpose                                            |
| ------------------------ | ------ | -------------------------------------------------- |
| `FLAVOR`                 | string | `dev` / `prod`; verified against the entrypoint    |
| `APP_NAME`               | string | `MaterialApp` title and on-screen labels           |
| `API_BASE_URL`           | string | Dio `baseUrl`; an empty value fails at startup     |
| `API_CONNECT_TIMEOUT_MS` | int    | Connect / send / receive timeout                   |
| `ENABLE_HTTP_LOGGING`    | bool   | Dio request/response logging (tokens are redacted) |

Both env files are committed and contain no secrets. Anything sensitive belongs in
`env/<flavor>.local.json`, which is gitignored.

The dev flavor points at [dummyjson.com](https://dummyjson.com), a public sample API, so the auth flow
works without a backend. Sign in with **`emilys` / `emilyspass`** (the login form is prefilled in dev).
Point `API_BASE_URL` at the real backend when it exists; the repository expects
`POST /auth/login` → `{"accessToken": ...}` and `GET /auth/me` → the user object.

## Structure

```
lib/
  main_dev.dart / main_prod.dart   flavor entrypoints (thin; call bootstrap)
  bootstrap.dart                   config validation, error hooks, DI, runApp
  app/
    app.dart                       MaterialApp.router + AuthBloc provider
    config/app_config.dart         compile-time env values
    di/injector.dart               get_it registrations
    router/                        GoRouter, auth redirect guard, route constants
  core/
    network/                       Dio factory, auth interceptor, ApiException
    storage/token_storage.dart     session token in SharedPreferences
  features/
    auth/                          bloc, repository, User, login + splash pages
    home/                          home page
```

### How the session works

1. `bootstrap()` builds the object graph and dispatches `AuthStarted`.
2. `AuthBloc` starts in `AuthStatus.unknown`; the router guard holds on `/splash`.
3. If a token is on disk, `GET /auth/me` validates it → `authenticated`, otherwise the token is
   dropped → `unauthenticated`.
4. The router's `refreshListenable` is fed by `AuthBloc.stream`, so every status change re-runs the
   redirect. Logging in or out navigates on its own — no `context.go` in the auth flow.
5. `AuthInterceptor` attaches `Authorization: Bearer <token>` to every request; on a `401` it clears
   the token and dispatches `AuthSessionExpired`, which sends the user back to `/login`.

## Tests

```bash
make verify        # analyze + test
make coverage      # writes coverage/lcov.info
make format-check  # fails on unformatted code (use in CI)
```

## Regenerating the iOS flavor setup

The six Xcode build configurations (`Debug`/`Profile`/`Release` × `dev`/`prod`) and the `dev` / `prod`
schemes were generated by `flutter_flavorizr` using [`flavorizr.yaml`](flavorizr.yaml), which is
restricted to the `ios:*` processors. Android flavors and all Dart code are hand-written — do not add
`android:*` or `flutter:*` instructions, they would overwrite those files.

```bash
make ios-flavors   # dart run flutter_flavorizr -f
```

`ASSETCATALOG_COMPILER_APPICON_NAME` resolves to `AppIcon-dev` / `AppIcon-prod`, so both icon sets must
exist in `ios/Runner/Assets.xcassets` or the iOS build fails. They currently hold copies of the default
icon — drop real dev artwork into `AppIcon-dev.appiconset` to tell the builds apart on the home screen.
