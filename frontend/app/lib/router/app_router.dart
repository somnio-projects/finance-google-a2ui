import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:go_router/go_router.dart';

/// Every route path in the app, as constants.
///
/// A path literal appears here and nowhere else, so a rename is one edit and
/// a typo is a compile error rather than a blank screen.
abstract final class AppRoutes {
  /// The portfolio surface — the app's home.
  static const String portfolio = '/';

  /// The conversation surface, where the agent answers in interfaces.
  static const String conversation = '/ask';

  /// The interactive order ticket.
  ///
  /// A surface of its own because its options must travel alone: the read
  /// endpoint applies one flat option set to every view in a request, so the
  /// ticket's `side` sent beside the portfolio's other views would 422 all of
  /// them (N-7, spec `frontend/0006` OD-5). The component still registers and
  /// still appears read-only in the portfolio list.
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
GoRouter buildRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? AppRoutes.portfolio,
    // The auth gate is a single `redirect`, not a check inside each screen
    // (ADR-I D-3 still binds). It returns null today because this skeleton has
    // no sign-in; when one lands it is this function that grows, and no
    // feature route changes.
    redirect: (context, state) => null,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.portfolio,
        // **No view ids here.** This route used to carry a hardcoded list, so
        // a component could be written, registered, covered and still be
        // invisible on screen with a green gate — nothing compared the router
        // against the registry. The page now asks the registry itself, which
        // makes the two impossible to disagree rather than merely tested for
        // agreement (`app_router_test.dart::every registered component is
        // reachable from the portfolio route`).
        builder: (context, state) => const PortfolioViewsPage(),
      ),
      GoRoute(
        path: AppRoutes.conversation,
        builder: (context, state) => const ConversationPage(),
      ),
      GoRoute(
        path: AppRoutes.orderTicket,
        builder: (context, state) => const OrderTicketPage(),
      ),
    ],
  );
}
