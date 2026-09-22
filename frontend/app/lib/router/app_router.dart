import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_page.dart';
import 'package:finance_app/features/catalog/view/catalog_page.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:go_router/go_router.dart';

export 'package:finance_app/router/app_routes.dart';

/// Every route path in the app, as constants.
///
/// A path literal appears here and nowhere else, so a rename is one edit and
/// a typo is a compile error rather than a blank screen.
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
GoRouter buildRouter({String? initialLocation, AuthGate? gate}) {
  return GoRouter(
    initialLocation: initialLocation ?? AppRoutes.home,
    refreshListenable: gate,
    // The auth gate is a single `redirect`, not a check inside each screen
    // (ADR-I D-3). With no gate — the tests that pump one route — every path
    // is open; with one, `AuthGate.redirectFor` is the whole decision.
    redirect: (context, state) => gate?.redirectFor(state.matchedLocation),
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
                // The catalog lives INSIDE this branch, so the tab bar stays
                // on screen while a reader is in the documentation.
                //
                // It used to be a pair of top-level routes, outside the
                // shell — defensible (a documentation surface is not a tab)
                // and a dead end in practice: neither page inherited the bar,
                // so from the index there was no way back into the app at
                // all. The browser's back button hides that on the web,
                // which is why it survived development.
                //
                // Under Home rather than a fifth branch: a fifth branch is a
                // fifth tab, and the catalog is a detour from the Home card
                // that opens it, not a destination of its own
                // (spec frontend/0021 OD-3).
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.catalogUnderHome,
                    // **No view ids here.** The index asks the backend's
                    // catalog and the registry, so a registered component is
                    // reachable by construction (`app_router_test.dart`).
                    builder: (context, state) => const CatalogPage(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: AppRoutes.catalogDetailUnderIndex,
                        builder: (context, state) => CatalogDetailPage(
                          viewId: state
                              .pathParameters[AppRoutes.catalogViewParameter]!,
                        ),
                      ),
                    ],
                  ),
                ],
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
                builder: (context, state) => const HoldingsPage(),
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
                builder: (context, state) => ConversationPage(
                  initialQuestion:
                      state.uri.queryParameters[AppRoutes.askParameter],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.orderTicket,
        builder: (context, state) => const OrderTicketPage(),
      ),
      GoRoute(
        path: AppRoutes.orderTicketV2,
        builder: (context, state) => const OrderTicketV2Page(),
      ),
    ],
  );
}
