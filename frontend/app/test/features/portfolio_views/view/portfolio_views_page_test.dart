import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
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
    testWidgets('builds a bloc and asks for what the registry registered', (
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
      // The page takes no view ids any more: it asks the registry, so a
      // registered component cannot be left unreachable by a second list.
      final registry = ComponentRegistry()
        ..register(const HoldingsAllocationComponent());

      await tester.pumpApp(
        const PortfolioViewsPage(),
        viewsRepository: repository,
        componentRegistry: registry,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PortfolioViewsView), findsOneWidget);
      // Captured rather than matched by value: the list is built at runtime,
      // and mocktail compares a non-matcher argument with `==`, which for a
      // `List` is identity.
      final captured = verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: captureAny(named: 'views'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, equals(<String>['holdings.allocation.v1']));
    });
  });
}
