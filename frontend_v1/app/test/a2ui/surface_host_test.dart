import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_notice.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/portfolio_summary/portfolio_summary_card.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/a2ui_fixtures.dart';
import 'surface_harness.dart';

/// Spec `frontend_v1/0001` AC-2, AC-3, AC-4 and AC-7 against the canonical
/// examples in `docs/a2ui/v1.0/examples/`.
void main() {
  group('SurfaceHost', () {
    testWidgets('draws the portfolio summary example verbatim, labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        surfaceOf(v1ExampleEvent('surface.portfolio_summary.json')),
      );
      expect(find.byType(PortfolioSummaryCard), findsOneWidget);
      expect(find.text(r'$482,915.20'), findsOneWidget);
      // N-4: the raw member never reaches a label.
      expect(find.textContaining('482915.2000'), findsNothing);
      // AC-7: the node carries its `accessibility.label`, ahead of the
      // content its children merge into it.
      expect(
        find.bySemanticsLabel(RegExp('^Portfolio summary')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('draws the ticket with its payoff child (ADR-M D-4)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        surfaceOf(v1ExampleEvent('surface.order_ticket_with_payoff.json')),
      );
      expect(find.byType(OrderTicketV2Card), findsOneWidget);
      expect(find.byType(PayoffChartCard), findsOneWidget);
      expect(find.byType(SurfaceNotice), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('^Multi leg order ticket')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Risk payoff chart')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('shows the skeleton while root is buffered', (tester) async {
      await pumpSurface(tester, const Surface(id: 's'));
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
    });

    testWidgets('a node whose data has not arrived waits as a skeleton', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        const Surface(id: 's').withComponents(<ComponentNode>[
          const ComponentNode(
            id: 'root',
            component: 'Section',
            children: <String>['a', 'b'],
          ),
          const ComponentNode(
            id: 'a',
            component: 'TaxLotTable',
            dataPath: '/a',
          ),
          const ComponentNode(id: 'b', component: 'TaxLotTable'),
        ]),
      );
      expect(find.byType(SurfaceSkeleton), findsNWidgets(2));
    });

    testWidgets('refuses a root the catalog does not allow there (AC-3)', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        surfaceOf(
          surfaceEvent(
            surfaceId: 's',
            component: 'RiskPayoffChart',
            payload: const <String, Object?>{'view': 'payoff.curve.v1'},
          ),
        ),
      );
      expect(find.byType(ComponentHost), findsNothing);
      expect(find.textContaining('UNALLOWED_PARENT'), findsOneWidget);
    });

    testWidgets('names a component that does not render its view', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        surfaceOf(
          surfaceEvent(
            surfaceId: 's',
            component: 'TaxLotTable',
            payload: const <String, Object?>{'view': 'portfolio.summary.v1'},
          ),
        ),
      );
      expect(
        find.textContaining('TaxLotTable does not render'),
        findsOneWidget,
      );
    });

    testWidgets('shows a payload that breaks the contract', (tester) async {
      final surface = const Surface(id: 's')
          .withComponents(<ComponentNode>[
            const ComponentNode(
              id: 'root',
              component: 'TaxLotTable',
              dataPath: '/root',
            ),
          ])
          .withData('/root', <String, Object?>{
            'view': 'taxlots.table.v1',
            'options': 'not an object',
            'payload': <String, Object?>{'no': 'view'},
          });
      await pumpSurface(tester, surface, onOptionChanged: (_, _, _) {});
      expect(find.textContaining('VALIDATION_FAILED'), findsOneWidget);
    });
  });
}
