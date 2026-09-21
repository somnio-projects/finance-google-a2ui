import 'package:finance_app/features/portfolio_views/view/portfolio_views_page.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(PortfolioViewsPage, () {
    testWidgets('builds a bloc and asks for the views it was given', (
      tester,
    ) async {
      final repository = _MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));

      await tester.pumpApp(
        const PortfolioViewsPage(views: <String>['holdings.allocation.v1']),
        viewsRepository: repository,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PortfolioViewsView), findsOneWidget);
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: const <String>['holdings.allocation.v1'],
        ),
      ).called(1);
    });
  });
}
