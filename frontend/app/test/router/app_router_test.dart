import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';
import 'app_router_harness.dart';

void main() {
  group(AppRoutes, () {
    test('exposes the portfolio path as a constant', () {
      // The path literal lives in one place, so a rename is one edit and a
      // typo is a compile error rather than a blank screen.
      expect(AppRoutes.home, equals('/'));
      expect(AppRoutes.portfolio, equals('/holdings'));
    });

    test('exposes the conversation path as a constant', () {
      expect(AppRoutes.conversation, equals('/ask'));
    });
  });

  group('buildRouter', () {
    late ViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );
    });

    test('declares every tab and the order ticket', () {
      final router = buildRouter();
      final paths = <String>{
        for (final route in router.configuration.routes)
          if (route is GoRoute) route.path,
        for (final route in router.configuration.routes)
          if (route is StatefulShellRoute)
            for (final branch in route.branches)
              for (final leaf in branch.routes.whereType<GoRoute>()) leaf.path,
      };
      expect(
        paths,
        containsAll(<String>[
          AppRoutes.home,
          AppRoutes.portfolio,
          AppRoutes.activity,
          AppRoutes.conversation,
          AppRoutes.orderTicket,
          AppRoutes.catalog,
        ]),
      );
      router.dispose();
    });

    testWidgets('places the home surface at the root location', (tester) async {
      await pumpRouter(tester, buildRouter(), repository: repository);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('honours an explicit initial location', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.portfolio),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsPage), findsOneWidget);
    });

    testWidgets('every registered component is reachable from the route', (
      tester,
    ) async {
      // The defect this closes: `app_router.dart` carried a hardcoded view id
      // and **nothing compared it with the registry**, so a component could be
      // added, registered, 100 %-covered and still never appear on screen with
      // a completely green gate. This asserts against the real registry the
      // app ships, so adding the seventh component extends the assertion for
      // free rather than needing a second edit here.
      final registry = buildComponentRegistry();
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.catalog),
        repository: repository,
        registry: registry,
      );
      await tester.pumpAndSettle();

      final captured = verify(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: captureAny(named: 'views'),
          options: any(named: 'options'),
        ),
      ).captured;
      final requested = <String>{
        for (final batch in captured) ...batch as List<String>,
      };
      expect(requested, equals(registry.viewIds.toSet()));
      expect(requested, isNotEmpty);
    });

    testWidgets('places the conversation surface at its own location', (
      tester,
    ) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.conversation),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationPage), findsOneWidget);
    });

    // Order ticket route: features/order_ticket/view/order_ticket_route_test.

    testWidgets('lets every route through while there is no sign-in', (
      tester,
    ) async {
      // The auth gate is a single `redirect` (ADR-I D-3) that returns null
      // today. This asserts the seam is wired and open, so the test that
      // closes it later has somewhere to go.
      final router = buildRouter();
      await pumpRouter(tester, router, repository: repository);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        equals(AppRoutes.home),
      );
    });
  });
}
