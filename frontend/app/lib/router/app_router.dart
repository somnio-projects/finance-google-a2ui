import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:go_router/go_router.dart';

/// Every route path in the app, as constants.
///
/// A path literal appears here and nowhere else, so a rename is one edit and
/// a typo is a compile error rather than a blank screen.
abstract final class AppRoutes {
  /// The Home tab — the app's first screen (spec 0026).
  static const String home = '/';

  /// The Holdings tab. Today it is the catalog list; the design's position
  /// list lands with its projection.
  static const String portfolio = '/holdings';

  /// The Activity tab.
  static const String activity = '/activity';

  /// The Assistant tab, where the agent answers in interfaces.
  static const String conversation = '/ask';

  /// The interactive order ticket.
  ///
  /// A surface of its own because its options must travel alone: the read
  /// endpoint applies one flat option set to every view in a request, so the
  /// ticket's `side` sent beside the portfolio's other views would 422 all of
  /// them (N-7, spec `frontend/0006` OD-5). It sits outside the tab shell.
  static const String orderTicket = '/order-ticket';
}

/// Builds the app's router.
///
/// `go_router` is the choice, and it is a **deliberate departure from ADR-I**,
/// which chose imperative `Navigator` for the other client. ADR-I's reason was
/// that adopting a router there meant rewriting existing navigation for no
/// present need; this app has no navigation to rewrite, is web-first, and
/// wants shareable URLs and working browser back/forward from the first
/// screen. ADR-I D-4 anticipated exactly this and asked that re-adopting
/// `go_router` be an amendment rather than a rediscovery — ADR-L D-5 is that
/// amendment, scoped to `frontend/`.
///
/// The four tabs are branches of one `StatefulShellRoute`, so each keeps its
/// scroll position and state while the reader moves between them, which is
/// what a tab bar promises (spec 0026).
GoRouter buildRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? AppRoutes.home,
    // The auth gate is a single `redirect`, not a check inside each screen
    // (ADR-I D-3 still binds). It returns null today because this skeleton has
    // no sign-in; when one lands it is this function that grows, and no
    // feature route changes.
    redirect: (context, state) => null,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.portfolio,
                // **No view ids here.** The page asks the registry itself, so
                // a registered component is reachable by construction
                // (`app_router_test.dart`).
                builder: (context, state) => const PortfolioViewsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.activity,
                builder: (context, state) => const ActivityPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.conversation,
                builder: (context, state) => const ConversationPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.orderTicket,
        builder: (context, state) => const OrderTicketPage(),
      ),
    ],
  );
}
