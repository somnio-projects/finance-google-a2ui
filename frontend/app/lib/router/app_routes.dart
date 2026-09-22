/// Every path the app navigates to, in one place.
///
/// A rename is one edit and a typo is a compile error rather than a blank
/// screen. Split from `app_router.dart` so the auth gate can name a route
/// without importing the pages (spec frontend/0008).
abstract final class AppRoutes {
  /// The Home tab — the root.
  static const String home = '/';

  /// The Holdings tab.
  static const String portfolio = '/holdings';

  /// The Activity tab.
  static const String activity = '/activity';

  /// The Assistant tab.
  static const String conversation = '/ask';

  /// The order ticket, outside the tabs.
  static const String orderTicket = '/order-ticket';

  /// The sign-in screen, outside the shell: no tab bar for a stranger.
  static const String signIn = '/sign-in';

  /// Whether [location] is the sign-in screen — the one path the gate treats
  /// differently from every other.
  static bool isSignIn(String location) => location == signIn;
}
