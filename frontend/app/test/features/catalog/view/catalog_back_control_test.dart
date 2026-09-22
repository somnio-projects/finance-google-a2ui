import 'package:finance_app/features/catalog/view/catalog_back_control.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The catalog's way out.
///
/// Its two routes sit OUTSIDE the `StatefulShellRoute`, so neither inherits
/// the tab bar. That is deliberate — a documentation surface is not a tab —
/// and it left both pages with no way back into the app: the index had no
/// control at all, and the detail page had only an 11 px monospace crumb
/// that does not read as one. On the web the browser's back button hides
/// this; in the app it is a dead end, and it was reported from both pages
/// (spec frontend/0021 OD-3).
void main() {
  /// A router whose two locations record where the control sent us.
  GoRouter routerRecording(List<String> visited, Widget bar) => GoRouter(
    initialLocation: '/bar',
    routes: <RouteBase>[
      GoRoute(
        path: '/bar',
        builder: (_, _) => Scaffold(body: bar),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) {
          visited.add(AppRoutes.home);
          return const Scaffold(body: Text('home'));
        },
      ),
      GoRoute(
        path: AppRoutes.catalog,
        builder: (_, _) {
          visited.add(AppRoutes.catalog);
          return const Scaffold(body: Text('index'));
        },
      ),
    ],
  );

  group(CatalogBackControl, () {
    testWidgets('returns to the app from the catalog index', (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: routerRecording(visited, const CatalogTopBar()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CatalogBackControl));
      await tester.pumpAndSettle();

      expect(visited, <String>[AppRoutes.home]);
    });

    testWidgets('returns to the index from a component page', (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: routerRecording(
            visited,
            const CatalogTopBar(component: 'Waterfall'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CatalogBackControl));
      await tester.pumpAndSettle();

      // The same place the crumb names, so the two controls on this bar
      // cannot disagree about what "back" means.
      expect(visited, <String>[AppRoutes.catalog]);
    });

    testWidgets('announces where it goes', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: routerRecording(<String>[], const CatalogTopBar()),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CatalogBackControl));
      expect(semantics.label, CatalogTopBar.backToApp);
      expect(CatalogTopBar.backToIndex, isNot(CatalogTopBar.backToApp));
    });
  });
}
