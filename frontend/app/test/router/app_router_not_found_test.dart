import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:finance_app/features/shell/view/not_found_page.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import 'app_router_harness.dart';

/// GGU-112: `/#/home` used to answer with go_router's own error widget —
/// black text on white, no theme, no chrome — for the most guessable path a
/// person can type.
void main() {
  group('buildRouter and a location no route claims', () {
    late MockViewsRepository repository;

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

    testWidgets('/home is Home (AC-1)', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: '/home'),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(NotFoundPage), findsNothing);
    });

    testWidgets('every declared alias lands on a screen (AC-2)', (
      tester,
    ) async {
      // The synonyms are data, so this walks them rather than naming a few:
      // an alias added to the map is covered the day it is added.
      for (final alias in AppRoutes.aliases.entries) {
        final router = buildRouter(initialLocation: alias.key);
        await pumpRouter(tester, router, repository: repository);
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          equals(alias.value),
          reason: alias.key,
        );
        expect(find.byType(NotFoundPage), findsNothing, reason: alias.key);
        router.dispose();
      }
    });

    testWidgets('/portfolio is the Holdings tab', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: '/portfolio'),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsPage), findsOneWidget);
    });

    testWidgets('anything else is the themed page with a way Home (AC-1)', (
      tester,
    ) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: '/nowhere/at/all'),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(find.text(NotFoundPage.title), findsOneWidget);
      // The path is echoed so a typo can be seen; the exception is not.
      expect(find.text('/nowhere/at/all'), findsOneWidget);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.textContaining('no routes for location'), findsNothing);

      await tester.tap(find.text(NotFoundPage.goHome));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('an alias still passes the gate: a stranger lands on sign-in', (
      tester,
    ) async {
      // The alias is a route, so the one auth redirect runs before it and
      // nothing about the shell is reachable by knowing a synonym.
      await pumpRouter(
        tester,
        buildRouter(
          initialLocation: '/home',
          gate: AuthGate(fakeAuthRepository()),
        ),
        repository: repository,
        auth: fakeAuthRepository(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });
}
