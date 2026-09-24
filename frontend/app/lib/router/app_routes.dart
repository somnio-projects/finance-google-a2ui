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

  /// The multi-leg draft order, outside the tabs for the same reason.
  static const String orderTicketV2 = '/order-ticket-v2';

  /// The component catalog index — every served view this build renders,
  /// one live card each (spec frontend/0016).
  static const String catalog = '/catalog';

  /// One component's catalog page; [catalogViewParameter] carries the id.
  static const String catalogDetail = '/catalog/:$catalogViewParameter';

  /// The catalog as a CHILD of the Home branch — the same location without
  /// the leading slash, which is what `GoRoute` wants from a sub-route.
  /// Nesting it there is what keeps the tab bar on screen inside the
  /// documentation (spec frontend/0021 OD-3).
  static const String catalogUnderHome = 'catalog';

  /// A component's page as a child of the index, for the same reason.
  static const String catalogDetailUnderIndex = ':$catalogViewParameter';

  /// The path parameter that names the view on a detail page.
  static const String catalogViewParameter = 'view';

  /// The sign-in screen, outside the shell: no tab bar for a stranger.
  static const String signIn = '/sign-in';

  /// The query key that carries a question into the assistant.
  static const String askParameter = 'ask';

  /// Whether [location] is the sign-in screen — the one path the gate treats
  /// differently from every other.
  static bool isSignIn(String location) => location == signIn;
}

/// The assistant's location with [question] ready to send — how the Home
/// chips and the Holdings hand-off open it (spec frontend/0009).
String askRoute(String question) => Uri(
  path: AppRoutes.conversation,
  queryParameters: <String, String>{AppRoutes.askParameter: question},
).toString();

/// The detail page of [viewId] — how a gallery card opens its component.
///
/// The id is a catalog id the backend served, passed through untouched; it
/// is never assembled here (N-6).
String catalogDetailRoute(String viewId) => '${AppRoutes.catalog}/$viewId';
