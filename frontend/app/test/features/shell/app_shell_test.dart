import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/shell/view/app_shell.dart';
import 'package:finance_app/features/shell/view/shell_tab_bar.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../router/app_router_harness.dart';

void main() {
  group(AppShell, () {
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

    testWidgets('a tab switches the branch and keeps the shell', (
      tester,
    ) async {
      await pumpRouter(tester, buildRouter(), repository: repository);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      final tab = find.descendant(
        of: find.byType(ShellTabBar),
        matching: find.text('Activity'),
      );
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityPage), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);

      // Tapping the current tab again is the go_router idiom for "back to
      // the branch root", and must not throw.
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityPage), findsOneWidget);
    });

    test("is at most the design's phone width", () {
      expect(AppShell.maxWidth, 430);
    });
  });
}
