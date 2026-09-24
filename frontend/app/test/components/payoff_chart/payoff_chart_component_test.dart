import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'payoff_chart_harness.dart';

void main() {
  group('PayoffChartComponent', () {
    const component = PayoffChartComponent();

    test('serves the frozen view id and A2UI name', () {
      expect(component.viewId, 'payoff.curve.v1');
      expect(component.a2uiComponent, 'RiskPayoffChart');
    });

    testWidgets('builds the card straight from a payload', (tester) async {
      // The seam the host actually calls. Asserted through `build` rather
      // than by constructing the card, because that is the path a registered
      // component reaches the screen by — and it was the one line of this
      // class no other test executed.
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              component.build(context, ViewPayload.fromJson(payoffExample())),
        ),
      );
      expect(find.byType(PayoffChartCard), findsOne);
      expect(
        find.text('Payoff across a price range: buy Vanguard S&P 500 ETF'),
        findsOne,
      );
    });

    test('binds every displayed string verbatim from the example', () {
      final data = payoffData();
      expect(
        data.title,
        'Payoff across a price range: buy Vanguard S&P 500 ETF',
      );
      expect(data.disclosure, startsWith('Illustrative linear spot payoff'));
      expect(
        data.totals.map((t) => '${t.label} ${t.text}'),
        containsAll(<String>[
          r'Entry price $528.00',
          r'Break-even price $528.00',
          r'Notional $500.00',
        ]),
      );
      expect(data.annotations.first.label, 'Entry');
      expect(data.annotations.first.text, r'$528.00');
    });

    test('keeps rows in arrival order and never re-ranks them (N-10)', () {
      final data = payoffData();
      expect(data.totals.map((t) => t.label), <String>[
        'Entry price',
        'Break-even price',
        'Notional',
      ]);
      expect(data.annotations.map((a) => a.label), <String>[
        'Entry',
        'Break-even',
        'Low',
        'High',
      ]);
    });

    test('reads the curve geometry from the raw decimals (AC-1)', () {
      final line = payoffData().lines.single;
      expect(line.name, 'Profit / loss');
      expect(line.points, hasLength(25));
      // The first sample of the published example: at $106.68 the position is
      // down $150. Both arrive as raw decimals and become coordinates only.
      expect(line.points.first.at, closeTo(369.6, 1e-9));
      expect(line.points.first.value, closeTo(-150, 1e-9));
      expect(line.points.last.at, closeTo(686.4, 1e-9));
      expect(line.points.last.value, closeTo(150, 1e-9));
    });

    test('carries one tick label per point, formatted by the backend', () {
      final line = payoffData().lines.single;
      expect(line.tickLabels, hasLength(line.points.length));
      expect(line.tickLabels.first, r'$369.60');
      expect(line.tickLabels.last, r'$686.40');
    });

    test('renders a payload with no series rather than throwing (AC-5)', () {
      final data = component.read(
        ViewPayload.fromJson(withoutSeries(payoffExample())),
      );
      expect(data.lines, isEmpty);
      expect(data.series, isEmpty);
      expect(data.tickLabels, isEmpty);
      expect(data.totals, isNotEmpty);
    });

    group('raises rather than reconstructing a missing field (N-3)', () {
      test('names the absent disclosure', () {
        expect(
          () => component.read(
            ViewPayload.fromJson(without(payoffExample(), 'disclosure')),
          ),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              'disclosure',
            ),
          ),
        );
      });

      test('names the absent title', () {
        expect(
          () => component.read(
            ViewPayload.fromJson(without(payoffExample(), 'title')),
          ),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              'title',
            ),
          ),
        );
      });

      test('names a point whose raw price is not a decimal', () {
        expect(
          () => component.read(
            ViewPayload.fromJson(withBadPoint(payoffExample())),
          ),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              'at.amount',
            ),
          ),
        );
      });
    });
  });
}
