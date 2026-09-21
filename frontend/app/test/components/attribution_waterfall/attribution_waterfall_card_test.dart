import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

void main() {
  group(AttributionWaterfallCard, () {
    late AttributionWaterfallData data;

    setUp(() {
      data = const AttributionWaterfallComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleFor('AttributionWaterfall'),
        ),
      );
    });

    Widget subject({
      void Function(String key)? onSegmentTap,
      String? initialSelectedKey,
    }) => Center(
      child: SizedBox(
        width: 571,
        child: AttributionWaterfallCard(
          data: data,
          onSegmentTap: onSegmentTap,
          initialSelectedKey: initialSelectedKey,
        ),
      ),
    );

    test('keeps the card chrome the design was measured at', () {
      // Constants, asserted as constants. A raster golden would prove these
      // too, and far less precisely — 16 px is exact, "looks the same" is
      // not. See the golden suite for why the chrome is not in a golden.
      expect(AttributionWaterfallCard.radius, 16);
      expect(
        AttributionWaterfallCard.padding,
        const EdgeInsets.fromLTRB(18, 16, 18, 14),
      );
    });

    testWidgets('shows the title and every annotation verbatim', (
      tester,
    ) async {
      await tester.pumpApp(subject());
      expect(find.text('Unrealised P/L attribution'), findsOneWidget);
      // N-9: notes are compliance statements and none is dropped.
      expect(find.text(r'Bitcoin $10,230.00'), findsOneWidget);
      expect(find.text(r'Ethereum -$2,797.50'), findsOneWidget);
      expect(find.text(r'Net $8,113.60'), findsOneWidget);
    });

    testWidgets('never shows a raw decimal', (tester) async {
      // N-4, the assertion the testing rule asks for by name: the raw
      // members reached the chart as geometry and must not be on screen.
      await tester.pumpApp(subject());
      expect(find.textContaining('56925.00'), findsNothing);
      expect(find.textContaining('65038.6'), findsNothing);
      expect(find.textContaining('-2797.500000'), findsNothing);
    });

    testWidgets('shows no detail until a band is tapped', (tester) async {
      await tester.pumpApp(subject());
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('reveals the tapped bucket and reports its key', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      final plot = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      // Seven bands over 571 px: the second band's centre is at ~122.
      await tester.tapAt(plot + const Offset(122, 100));
      await tester.pumpAndSettle();
      expect(tapped, <String>['BTC']);
      expect(find.byType(AttributionWaterfallDetail), findsOneWidget);
      expect(find.text(r'$67,155.00'), findsOneWidget);
    });

    testWidgets('a second tap on the same bucket clears the selection', (
      tester,
    ) async {
      await tester.pumpApp(subject(initialSelectedKey: 'BTC'));
      expect(find.byType(AttributionWaterfallDetail), findsOneWidget);
      final plot = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      await tester.tapAt(plot + const Offset(122, 100));
      await tester.pumpAndSettle();
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('a total is not drillable', (tester) async {
      // Neither endpoint has a `key` in the contract, because there is
      // nothing to drill into.
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      final plot = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      await tester.tapAt(plot + const Offset(40, 100));
      await tester.pumpAndSettle();
      expect(tapped, isEmpty);
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('ignores a selected key that is not in the walk', (
      tester,
    ) async {
      await tester.pumpApp(subject(initialSelectedKey: 'NOPE'));
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('colours a gain with the gain mark', (tester) async {
      await tester.pumpApp(subject(initialSelectedKey: 'BTC'));
      final gain = tester.widget<Text>(find.text(r'$10,230.00'));
      expect(gain.style?.color, ChartTokens.light.barGain);
    });

    testWidgets('colours a loss with the loss mark', (tester) async {
      // A separate test rather than a second pump: the card's `State`
      // survives a re-pump of the same widget type, so its selection would
      // not change and the assertion would quietly read the first one.
      await tester.pumpApp(subject(initialSelectedKey: 'ETH'));
      final loss = tester.widget<Text>(find.text(r'-$2,797.50'));
      expect(loss.style?.color, ChartTokens.light.barLoss);
    });
  });
}
