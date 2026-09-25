import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'attribution_waterfall_harness.dart';

/// The walks that are not the happy one (spec frontend/0028 AC-4).
///
/// Built from literals rather than the catalog snapshot on purpose: the
/// backend publishes one example, and these are the *shapes* the same
/// contract can produce — all up, all down, one bucket, many buckets, a net
/// that did not move. Every figure is still a string the payload would have
/// carried; nothing here is computed.
void main() {
  Future<void> pump(
    WidgetTester tester,
    AttributionWaterfallData data, {
    String? selected,
    double width = 380,
  }) => tester.pumpApp(
    Center(
      child: SizedBox(
        width: width,
        child: AttributionWaterfallCard(
          data: data,
          initialSelectedKey: selected,
        ),
      ),
    ),
    surfaceSize: const Size(900, 900),
  );

  testWidgets('an all-positive walk draws every bucket', (tester) async {
    final data = walk(<AttributionStep>[
      bucket('AAA', WaterfallStepKind.gain, 101000),
      bucket('BBB', WaterfallStepKind.gain, 102000),
      bucket('CCC', WaterfallStepKind.gain, 103240),
    ]);
    await pump(tester, data);
    expect(tester.takeException(), isNull);
    for (final key in <String>['AAA', 'BBB', 'CCC']) {
      expect(find.text('$key Holdings Incorporated'), findsOneWidget);
    }
  });

  testWidgets('an all-negative walk draws every bucket', (tester) async {
    final data = walk(<AttributionStep>[
      bucket('AAA', WaterfallStepKind.loss, 99000),
      bucket('BBB', WaterfallStepKind.loss, 98000),
    ], direction: NetDirection.down);
    await pump(tester, data, selected: 'AAA');
    expect(tester.takeException(), isNull);
    expect(find.text('AAA Holdings Incorporated'), findsOneWidget);
    expect(find.text('BBB Holdings Incorporated'), findsOneWidget);
    // The net takes the loss mark from the declared direction, and the
    // selected bucket's contribution takes it too.
    expect(
      tester.widget<Text>(find.text(r'-$3,240 · -0.68%')).style?.color,
      ChartTokens.light.barLoss,
    );
    expect(
      tester.widget<Text>(find.text(r'-$1,000')).style?.color,
      ChartTokens.light.barLoss,
    );
  });

  testWidgets('a single bucket still selects and shows its detail', (
    tester,
  ) async {
    final data = walk(<AttributionStep>[
      bucket('ONE', WaterfallStepKind.gain, 103240),
    ]);
    await pump(tester, data, selected: 'ONE');
    expect(find.text('ONE · ONE Holdings Incorporated'), findsOneWidget);
    expect(find.text(r'+1.0% · 10 sh · $100.00'), findsOneWidget);
  });

  testWidgets('twenty buckets ellipsise their names instead of overflowing', (
    tester,
  ) async {
    final data = walk(<AttributionStep>[
      for (var index = 0; index < 20; index++)
        bucket('B$index', WaterfallStepKind.gain, 100000 + index * 100),
    ]);
    await pump(tester, data);
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text('B0 Holdings Incorporated'));
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.maxLines, 1);
  });

  testWidgets('a net that did not move is muted and carries no glyph', (
    tester,
  ) async {
    final data = walk(<AttributionStep>[
      bucket('AAA', WaterfallStepKind.gain, 100500),
      bucket('BBB', WaterfallStepKind.loss, 100000),
    ], direction: NetDirection.flat);
    await pump(tester, data);
    expect(find.text(r'$0 · 0.00%'), findsOneWidget);
    expect(find.textContaining('▲'), findsNothing);
  });
}
