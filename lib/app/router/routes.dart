/// Route paths and names. Always navigate with these constants
/// (`context.goNamed(Routes.lobbiesName)`) rather than raw strings.
abstract final class Routes {
  static const String splash = '/splash';
  static const String splashName = 'splash';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String register = '/register';
  static const String registerName = 'register';

  // Dashboard tabs. Each is a branch of the shell route, so switching tabs
  // preserves the others' navigation stack and scroll position.

  static const String lobbies = '/lobbies';
  static const String lobbiesName = 'lobbies';

  static const String myLobbies = '/my-lobbies';
  static const String myLobbiesName = 'my-lobbies';

  static const String notifications = '/notifications';
  static const String notificationsName = 'notifications';

  static const String profile = '/profile';
  static const String profileName = 'profile';

  /// Pushed over the shell, so it covers the tab bar.
  static const String lobbyDetail = '/lobbies/:lobbyId';
  static const String lobbyDetailName = 'lobby-detail';

  /// The `+` in the middle of the tab bar. Deliberately *not* `/lobbies/create`
  /// — that would collide with [lobbyDetail]'s `:lobbyId`.
  static const String createLobby = '/create-lobby';
  static const String createLobbyName = 'create-lobby';

  /// Where a signed-in user lands. The auth guard redirects here.
  static const String home = lobbies;
}
