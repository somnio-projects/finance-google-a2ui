import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import 'app_router_harness.dart';

void main() {
  group('buildRouter sign-in', () {
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

    testWidgets('serves the sign-in screen outside the shell', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.signIn),
        repository: repository,
        auth: fakeAuthRepository(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('serves the catalog index at its own location', (tester) async {
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.catalog),
        repository: repository,
        auth: fakeAuthRepository(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioViewsPage), findsOneWidget);
    });
  });
}
