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

/// The one breakpoint in this app (spec frontend/0028 OD-4, AC-3): the same
/// selection, the same strings, two presentations.
void main() {
  late AttributionWaterfallData data;

  setUp(() {
    data = const AttributionWaterfallComponent().read(
      ViewPayload.fromJson(
        CatalogSnapshot.load().exampleForView('attribution.waterfall.v1'),
      ),
    );
  });

  Widget subject(double width) => Center(
    child: SizedBox(
      width: width,
      child: AttributionWaterfallCard(data: data, initialSelectedKey: 'BTC'),
    ),
  );

  group('the detail presentation', () {
    testWidgets('is the footer strip one pixel under the threshold', (
      tester,
    ) async {
      await tester.pumpApp(
        subject(AttributionWaterfallCard.calloutMinWidth - 1),
        surfaceSize: const Size(900, 900),
      );
      expect(find.byType(AttributionWaterfallDetail), findsOneWidget);
      expect(find.byType(AttributionWaterfallCallout), findsNothing);
    });

    testWidgets('is the callout at the threshold itself', (tester) async {
      await tester.pumpApp(
        subject(AttributionWaterfallCard.calloutMinWidth),
        surfaceSize: const Size(900, 900),
      );
      expect(find.byType(AttributionWaterfallCallout), findsOneWidget);
      expect(find.byType(AttributionWaterfallDetail), findsNothing);
    });

    testWidgets('prints the same payload strings either way', (tester) async {
      // The presentations differ; what they say does not. A callout that
      // dropped the sentence would look fine and be a different component.
      for (final width in <double>[380, 700]) {
        await tester.pumpApp(subject(width), surfaceSize: const Size(900, 900));
        expect(find.text('BTC · Bitcoin'), findsOneWidget);
        expect(find.text(r'+54.08% · 2.1 BTC · $64,250.00'), findsOneWidget);
        expect(find.text(r'$47,359.20'), findsWidgets);
      }
    });

    testWidgets('renders both widths in dark without overflowing', (
      tester,
    ) async {
      for (final width in <double>[380, 700]) {
        await tester.pumpApp(
          subject(width),
          brightness: Brightness.dark,
          surfaceSize: const Size(900, 900),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('BTC · Bitcoin'), findsOneWidget);
      }
    });
  });
}
