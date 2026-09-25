import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// How many bands the example walks: a start total, one per holding, an end.
///
/// **Read from the example, never written down.** This was the literal `16`
/// of the equity seed, and the crypto seed (spec `backend/0044`) walks nine.
/// A hardcoded count does not fail on the band it names — it silently taps
/// somewhere else on the plot and the assertion reports an empty selection,
/// which reads like a broken tap handler rather than a stale constant.
int get bandCount => const AttributionWaterfallComponent()
    .read(
      ViewPayload.fromJson(
        CatalogSnapshot.load().exampleForView('attribution.waterfall.v1'),
      ),
    )
    .steps
    .length;

/// The centre of band [index] of the [bandCount] the example walks, measured
/// off the plot the test pumped.
Offset bandCentre(WidgetTester tester, int index) {
  final plot = tester.getRect(find.byKey(WaterfallChart.plotKey));
  final band = plot.width / bandCount;
  return Offset(plot.left + band * (index + 0.5), plot.center.dy);
}

/// A card narrow enough to show the footer strip rather than the callout.
const double phoneWidth = 380;

void main() {
  group(AttributionWaterfallCard, () {
    late AttributionWaterfallData data;

    setUp(() {
      data = const AttributionWaterfallComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleForView('attribution.waterfall.v1'),
        ),
      );
    });

    Widget subject({
      void Function(String key)? onSegmentTap,
      String? initialSelectedKey,
      double width = phoneWidth,
    }) => Center(
      child: SizedBox(
        width: width,
        child: AttributionWaterfallCard(
          data: data,
          onSegmentTap: onSegmentTap,
          initialSelectedKey: initialSelectedKey,
        ),
      ),
    );

    test('keeps the card chrome the design was measured at', () {
      expect(AttributionWaterfallCard.radius, 16);
      expect(
        AttributionWaterfallCard.padding,
        const EdgeInsets.fromLTRB(18, 16, 18, 14),
      );
      expect(AttributionWaterfallCard.calloutMinWidth, 520);
    });

    testWidgets('shows the title and every annotation verbatim', (
      tester,
    ) async {
      await tester.pumpApp(subject());
      expect(find.text('Unrealised P/L attribution'), findsOneWidget);
      // N-9: notes are compliance statements and none is dropped.
      expect(find.text(r'Bitcoin $47,359.20'), findsOneWidget);
      expect(find.text(r'Ethereum $21,000.00'), findsOneWidget);
      expect(find.text(r'Net $61,204.05'), findsOneWidget);
    });

    testWidgets('never shows a raw decimal', (tester) async {
      // N-4, the assertion the testing rule asks for by name: the raw
      // members reached the chart as geometry and must not be on screen.
      await tester.pumpApp(subject());
      expect(find.textContaining('421711.15'), findsNothing);
      expect(find.textContaining('482915.2'), findsNothing);
      expect(find.textContaining('-10500.000000'), findsNothing);
    });

    testWidgets('shows no detail until a band is tapped', (tester) async {
      await tester.pumpApp(subject());
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
      expect(find.byType(AttributionWaterfallCallout), findsNothing);
    });

    testWidgets('reveals the tapped bucket and reports its key', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      // Nine bands over the plot: the second is BTC, the first holding.
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      expect(tapped, <String>['BTC']);
      expect(find.byType(AttributionWaterfallDetail), findsOneWidget);
      expect(find.text('BTC · Bitcoin'), findsOneWidget);
      expect(find.text(r'+54.08% · 2.1 sh · $64,250.00'), findsOneWidget);
    });

    testWidgets('a second tap on the same bucket clears the selection', (
      tester,
    ) async {
      await tester.pumpApp(subject(initialSelectedKey: 'BTC'));
      expect(find.byType(AttributionWaterfallDetail), findsOneWidget);
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('a total is not drillable', (tester) async {
      // Neither endpoint has a `key` in the contract, because there is
      // nothing to drill into.
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      await tester.tapAt(bandCentre(tester, 0));
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
  });
}
