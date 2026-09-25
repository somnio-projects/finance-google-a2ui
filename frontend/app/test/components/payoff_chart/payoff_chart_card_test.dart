import 'package:finance_app/charts/payoff_chart.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'payoff_chart_harness.dart';

void main() {
  group('PayoffChartCard', () {
    Widget subject({double width = 1024, Map<String, dynamic>? payload}) =>
        Center(
          child: SizedBox(
            width: width,
            child: PayoffChartCard(
              data: payload == null
                  ? payoffData()
                  : const PayoffChartComponent().read(
                      ViewPayload.fromJson(payload),
                    ),
            ),
          ),
        );

    testWidgets('renders the title and the plot', (tester) async {
      await tester.pumpApp(subject());
      expect(find.text('Payoff across a price range: buy Solana'), findsOne);
      expect(find.byKey(PayoffChart.plotKey), findsOne);
    });

    testWidgets('renders every total as label and figure (AC-4)', (
      tester,
    ) async {
      await tester.pumpApp(subject());
      expect(find.text('Entry price'), findsOne);
      expect(find.text('Break-even price'), findsOne);
      expect(find.text('Notional'), findsOne);
      expect(find.text(r'$500.00'), findsOne);
      // Four rows carry the figure $152.40 — the entry and break-even
      // totals, and the entry and break-even annotations — and all four are
      // drawn. On a fee-free spot order the break-even sits exactly on the
      // entry, so the repetition is the payload telling the truth; the card
      // never de-duplicates or picks among the rows it was sent (N-10).
      expect(find.text(r'$152.40'), findsNWidgets(4));
    });

    testWidgets('renders every annotation verbatim (N-9)', (tester) async {
      await tester.pumpApp(subject());
      expect(find.text('Entry'), findsOne);
      expect(find.text('Break-even'), findsOne);
      expect(find.text(r'at $106.68: -$150.00'), findsOne);
      expect(find.text(r'at $198.12: $150.00'), findsOne);
    });

    testWidgets('renders the disclosure in full and never truncated', (
      tester,
    ) async {
      await tester.pumpApp(subject());
      final text = tester.widget<Text>(
        find.textContaining('Illustrative linear spot payoff'),
      );
      expect(text.data, payoffData().disclosure);
      // The sentence that stops a straight line reading as an options payoff.
      expect(text.data, contains('no strike, no expiry'));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);
    });

    testWidgets('names each series in the legend', (tester) async {
      await tester.pumpApp(subject());
      expect(find.text('Profit / loss'), findsOne);
      expect(find.text('Loss'), findsOne);
      expect(find.text('Gain'), findsOne);
    });

    testWidgets('never puts a raw decimal on screen (N-4)', (tester) async {
      await tester.pumpApp(subject());
      final drawn = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toSet();
      for (final raw in rawDecimalsOf(payoffExample())) {
        expect(
          drawn,
          isNot(contains(raw)),
          reason: 'the raw decimal "$raw" reached the widget tree',
        );
      }
      // The sharpest case: `0E-30` is what the break-even point's raw value
      // looks like, and `$0.00` is what a reader must see instead.
      expect(drawn, isNot(contains('0E-30')));
    });

    testWidgets('lays out at phone width without overflowing (AC-6)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(subject(width: 360));
      expect(tester.takeException(), isNull);
      expect(find.byKey(PayoffChart.plotKey), findsOne);
    });

    testWidgets('lays out at desktop width without overflowing (AC-6)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(subject());
      expect(tester.takeException(), isNull);
      expect(find.byKey(PayoffChart.plotKey), findsOne);
    });

    testWidgets('renders a payload with no series (AC-5)', (tester) async {
      await tester.pumpApp(subject(payload: withoutSeries(payoffExample())));
      expect(tester.takeException(), isNull);
      expect(find.byKey(PayoffChart.plotKey), findsOne);
      expect(find.text('Entry price'), findsOne);
      expect(find.text('Profit / loss'), findsNothing);
    });

    testWidgets('draws in the dark palette too', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      expect(find.byKey(PayoffChart.plotKey), findsOne);
    });
  });
}
