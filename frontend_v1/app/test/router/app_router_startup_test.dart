import 'dart:async';

import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:finance_app/features/shell/view/not_found_page.dart';
import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/features/startup/view/startup_view.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';
import '../helpers/startup_fakes.dart';
import 'app_router_harness.dart';

/// GGU-154, GGU-159, GGU-163: what a cold load does with a stored session.
void main() {
  group('buildRouter at start-up', () {
    late MockViewsRepository views;

    setUp(() {
      views = MockViewsRepository();
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );
    });

    Future<GoRouter> coldLoad(
      WidgetTester tester,
      String location,
      AuthRepository auth,
    ) async {
      final router = buildRouter(
        initialLocation: location,
        gate: AuthGate(auth),
      );
      addTearDown(router.dispose);
      await pumpRouter(tester, router, repository: views, auth: auth);
      unawaited(auth.restore());
      await tester.pump();
      return router;
    }

    String at(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('a restoring session never draws sign-in (GGU-163)', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final auth = startupRepository(answers: <Object>[pending]);
      final router = await coldLoad(tester, '/holdings', auth);
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(StartupView), findsOneWidget);
      expect(find.bySemanticsLabel(StartupView.loadingLabel), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
      // ...and the cold load of /#/holdings lands on Holdings (GGU-154).
      pending.complete(admitted());
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsPage), findsOneWidget);
      expect(at(router), '/holdings');
    });

    testWidgets('a reload through the sign-in gateway keeps the tab', (
      tester,
    ) async {
      final router = await coldLoad(
        tester,
        '/sign-in?from=%2Fholdings',
        startupRepository(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsPage), findsOneWidget);
      expect(at(router), '/holdings');
    });

    testWidgets('an unknown route still resolves inside the app', (
      tester,
    ) async {
      final router = await coldLoad(tester, '/nowhere', startupRepository());
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(at(router), '/nowhere');
    });

    testWidgets('a 429 is a retry, not sign-in, and retry lands (GGU-159)', (
      tester,
    ) async {
      final auth = startupRepository(
        answers: <Object>[rateLimited(), admitted()],
      );
      final router = await coldLoad(tester, '/', auth);
      await tester.pump();
      expect(find.text('Too many requests. Try again shortly.'), findsOne);
      expect(find.byType(SignInPage), findsNothing);
      // Retry-After: no button until the window has passed.
      expect(find.text(TabFailure.retryLabel), findsNothing);
      await tester.pump(const Duration(seconds: 60));
      await tester.tap(find.text(TabFailure.retryLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(at(router), '/');
    });

    testWidgets('a dropped connection is a retry at once', (tester) async {
      final auth = startupRepository(answers: <Object>[StateError('net')]);
      await coldLoad(tester, '/activity', auth);
      await tester.pump();
      expect(find.text('the server could not be reached'), findsOneWidget);
      expect(find.text(TabFailure.retryLabel), findsOneWidget);
      expect(auth.state.session, isNotNull);
    });

    testWidgets('only a definitive answer reaches sign-in', (tester) async {
      final auth = startupRepository(
        answers: <Object>[problem(403, 'forbidden', 'Not for you.')],
      );
      final router = await coldLoad(tester, '/ask', auth);
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
      expect(at(router), '/sign-in?from=%2Fask');
    });
  });
}
