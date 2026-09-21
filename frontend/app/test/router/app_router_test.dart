import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

class _MockAgentRepository extends Mock implements AgentRepository;

void main() {
  group(AppRoutes, () {
    test('exposes the portfolio path as a constant', () {
      // The path literal lives in one place, so a rename is one edit and a
      // typo is a compile error rather than a blank screen.
      expect(AppRoutes.portfolio, equals('/'));
    });

    test('exposes the conversation path as a constant', () {
      expect(AppRoutes.conversation, equals('/ask'));
    });
  });

  group('buildRouter', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));
    });

    test('declares the portfolio route', () {
      final router = buildRouter();
      final paths = router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(paths, contains(AppRoutes.portfolio));
      router.dispose();
    });

    Future<void> pumpRouter(
      WidgetTester tester,
      GoRouter router, {
      ComponentRegistry? registry,
    }) {
      return tester.pumpWidget(
        MultiRepositoryProvider(
          providers: <RepositoryProvider<dynamic>>[
            RepositoryProvider<ViewsRepository>.value(value: repository),
            RepositoryProvider<AgentRepository>.value(
              value: _MockAgentRepository(),
            ),
            RepositoryProvider<ComponentRegistry>.value(
              value: registry ?? ComponentRegistry(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    testWidgets('places the portfolio surface at the root location', (
      tester,
    ) async {
      await pumpRouter(tester, buildRouter());
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioViewsPage), findsOneWidget);
    });

    testWidgets('honours an explicit initial location', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.portfolio),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioViewsPage), findsOneWidget);
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
      await pumpRouter(tester, buildRouter(), registry: registry);
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
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationPage), findsOneWidget);
    });

    testWidgets('lets every route through while there is no sign-in', (
      tester,
    ) async {
      // The auth gate is a single `redirect` (ADR-I D-3) that returns null
      // today. This asserts the seam is wired and open, so the test that
      // closes it later has somewhere to go.
      final router = buildRouter();
      await pumpRouter(tester, router);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        equals(AppRoutes.portfolio),
      );
    });
  });
}
