import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_marks.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'payoff_chart_harness.dart';

/// GGU-146 — the axis, the markers and the region words the design draws.
///
/// All four are payload fields the client could not have invented: a ladder
/// it chose would be a computed figure (N-2), and a word it wrote would be
/// copy the server owns (N-1). These assert that each arrives and that none
/// is authored here.
void main() {
  group('PayoffChartComponent reads the furniture', () {
    test('binds every rung the payload published, in arrival order', () {
      final example = payoffExample();
      final published = (example['value_ticks'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final data = payoffData();

      expect(published, isNotEmpty);
      expect(
        data.rungs.map((rung) => rung.display),
        published.map((tick) => tick['display']),
      );
    });

    test('places both markers by field name, never by matching a label', () {
      final data = payoffData();
      final markers = payoffExample()['markers']! as Map<String, dynamic>;
      final breakEven = markers['break_even']! as Map<String, dynamic>;

      expect(data.breakEven?.label, breakEven['label']);
      expect(
        data.breakEven?.display,
        (breakEven['at']! as Map<String, dynamic>)['display'],
      );
      expect(data.current, isNotNull);
    });

    test('takes the region words from the payload, not from a constant', () {
      final zones = payoffExample()['zones']! as Map<String, dynamic>;
      final data = payoffData();

      expect(data.lossWord, zones['loss']);
      expect(data.gainWord, zones['gain']);
      expect(data.lossWord, isNotEmpty);
    });

    test('raises the path instead of guessing a missing marker', () {
      // N-3: the card cannot place a rule it was not told about, and the
      // exception names the field so the gap is legible rather than silent.
      expect(
        () => const PayoffChartComponent().read(
          ViewPayload.fromJson(without(payoffExample(), 'markers')),
        ),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.message,
            'the path it names',
            contains('markers'),
          ),
        ),
      );
    });

    test('a rung and a marker are values over what the payload sent', () {
      // Equality goes through `props`, which is what lets a bloc emit the
      // same model twice without the card repainting.
      const rung = PayoffRung(at: 0, display: r'$0.00');
      const marker = PayoffMarker(label: 'A', display: 'B', at: 1);

      expect(rung, const PayoffRung(at: 0, display: r'$0.00'));
      expect(rung, isNot(const PayoffRung(at: 1, display: r'$0.00')));
      expect(marker, const PayoffMarker(label: 'A', display: 'B', at: 1));
      expect(
        marker,
        isNot(const PayoffMarker(label: 'A', display: 'B', at: 2)),
      );
    });

    test("the break-even's caption is two backend strings, joined", () {
      // The client writes no word of it: the label is `markers.break_even.
      // label` and the price is that marker's own `display`.
      const marker = PayoffMarker(
        label: 'Break-even',
        display: r'$152.40',
        at: 152.4,
      );

      expect(marker.caption, r'Break-even $152.40');
    });
  });

  group(PayoffChartCard, () {
    testWidgets('puts the legend opposite the title, not under the plot', (
      tester,
    ) async {
      // The design's arrangement: with two series the key is needed before
      // looking at the lines, not after.
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 640,
            child: PayoffChartCard(data: payoffData()),
          ),
        ),
        surfaceSize: const Size(900, 1400),
      );
      final title = tester.getRect(find.text(payoffData().title));
      final legend = tester.getRect(find.text(payoffData().lines.first.name));

      expect(legend.left, greaterThan(title.left));
      expect(legend.top, lessThan(title.bottom + 8));
    });
  });
}
