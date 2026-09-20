import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:go_router/go_router.dart';

/// Every route path in the app, as constants.
///
/// A path literal appears here and nowhere else, so a rename is one edit and
/// a typo is a compile error rather than a blank screen.
abstract final class AppRoutes {
  /// The portfolio surface — the app's home.
  static const String portfolio = '/';
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
        builder: (context, state) => const PortfolioViewsPage(
          // The one view this build renders. The list is a *request*, not a
          // catalog: ids come from `GET /v1/views` and the client invents
          // none (N-6).
          views: <String>['holdings.allocation.v1'],
        ),
      ),
    ],
  );
}
