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

The dev flavor points at `http://localhost:8080/api/v1` — the Grip Club backend running on your
machine. `/api/v1` is part of the base URL, so repository code uses bare paths like `/auth/login`.

The **Android emulator cannot reach `localhost`**; it sees the host as `10.0.2.2`. Override the one
key rather than editing the committed env file:

```bash
make run-dev API_URL=http://10.0.2.2:8080/api/v1
```

Plaintext HTTP is allowed only where it has to be: `usesCleartextTraffic` lives in the **debug**
Android manifest, and iOS uses `NSAllowsLocalNetworking`, which relaxes ATS for loopback addresses
only. Release builds still require HTTPS.

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
    auth/                          bloc, repository, User, splash + maintenance + login + register pages
    home/                          home page
```

### How the session works

1. `bootstrap()` builds the object graph and dispatches `AuthStarted`.
2. `AuthBloc` starts in `AuthStatus.unknown`; the router guard holds on `/splash`. The native launch
   screen paints the same colour, so the OS → Flutter handover is invisible.
3. If an unexpired token is on disk, `GET /me` resolves it into a profile → `authenticated`. No token,
   or one whose stored `expires_at` has passed → `unauthenticated`, after a bare `GET /me` used only
   as a reachability probe (see below).
4. If the backend does not answer — a timeout, a dead connection, a rejected certificate or a `5xx` —
   the status becomes `unavailable` and the guard parks the app on `/maintenance`. A `4xx` is *not*
   an outage and still lands on `/login` with its message. **Retry** re-dispatches `AuthStarted`,
   which puts the status back to `unknown`; the guard returns to `/splash` and the launch runs again
   from the top. `/maintenance` is unreachable in any other state.
5. The router's `refreshListenable` is fed by `AuthBloc.stream`, so every status change re-runs the
   redirect. Logging in, registering or signing out navigates on its own — no `context.go` in the
   auth flow. `/login` and `/register` are the only routes reachable while signed out.
6. `AuthInterceptor` attaches `Authorization: Bearer <token>` to every request; on a `401` it clears
   the token and dispatches `AuthSessionExpired`, which sends the user back to `/login`.

A signed-out launch has no session to restore, but it still has to notice a dead backend — otherwise
a fresh install meets a login form that cannot possibly work. So it calls `AuthRepository.ensureServerReachable()`,
a bare `GET /me`: **any** HTTP response proves the server is up, so the `401` it earns without a token
is swallowed, and only a no-response failure or a `5xx` is rethrown. It reuses `/me` because the API
exposes no health endpoint; give it one and this is the single place to point at it.

The maintenance screen shows the transport-level reason (`No internet connection.`) under the
maintenance copy, so an offline user is not told the servers are down — the two failures are
indistinguishable from the client.

`POST /auth/login` and `POST /auth/register` both return a token plus a *thin* user, so the
repository persists the token and then fetches `GET /me` for the full profile — one `User` shape
everywhere. Failures arrive as `{"error": {code, message, details}}`; `ApiException` carries `code`
and `details` through to the forms, which show `validation_failed` and `email_taken` on the field
they belong to. See [`API.md`](API.md) for the full contract.

### Home location

Sign-up is a two-step `Stepper`: credentials first, then the country and city the user is based in.
Both location fields are optional — a blank one is dropped from `POST /auth/register` rather than
sent — and each step validates its own `Form`, so a rejected email sends the flow back to the step
that owns the field.

That pair is the user's home location, editable afterwards from the Profile tab (`PATCH /me`):

- **city** is the saved browse filter the Lobbies tab starts from; empty means every city.
- **country + city** prefill the create-lobby form. The prefill is client-side and visible: the form
  always sends both fields, so the API's own defaulting — which only applies when *neither* is sent —
  never comes into play, and the user can type over either one before saving.

### Native launch screen

Generated by `flutter_native_splash` from [`flutter_native_splash.yaml`](flutter_native_splash.yaml):

```bash
make splash   # re-run after make ios-flavors, which rewrites iOS project files
```

Colour-only for now. To add a logo, drop it at `assets/splash/logo.png`, declare the asset in
`pubspec.yaml`, uncomment the `image` keys and re-run. The colour must stay in step with
`SplashPage.backgroundColor`.

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
