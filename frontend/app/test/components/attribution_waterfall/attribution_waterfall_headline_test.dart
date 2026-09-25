import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_notes.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pill.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// GGU-100 (spec frontend/0014): the headline, the selected caption and the
/// per-step detail are **bound** from the new contract fields — the card
/// computes none of them (N-1..N-4). Beside the component and card suites,
/// under the 150-line budget.
void main() {
  const component = AttributionWaterfallComponent();
  late Map<String, dynamic> example;

  setUp(() {
    example = CatalogSnapshot.load().exampleForView('attribution.waterfall.v1');
  });

  group('the headline', () {
    test('is read from `net`, signs included, and its direction', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.net.label, 'Net');
      expect(data.net.amountDisplay, r'+$61,204.05');
      expect(data.net.percentDisplay, '+14.51%');
      expect(data.net.direction, NetDirection.up);
    });

    test('raises a `net.direction` the contract does not declare', () {
      final net = Map<String, dynamic>.from(
        example['net'] as Map<String, dynamic>,
      )..['direction'] = 'sideways';
      expect(
        () => component.read(
          ViewPayload.fromJson(<String, dynamic>{...example, 'net': net}),
        ),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'net.direction',
          ),
        ),
      );
    });

    testWidgets('is the pill in the header, and the notes sit below', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 571,
            child: AttributionWaterfallCard(
              data: component.read(ViewPayload.fromJson(example)),
            ),
          ),
        ),
      );
      expect(find.text(r'▲ Net +$61,204.05 (+14.51%)'), findsOneWidget);
      // The notes moved, they were not dropped (N-9, spec 0014 OD-2).
      expect(find.byType(AttributionWaterfallNotes), findsOneWidget);
      expect(find.text(r'Net $61,204.05'), findsOneWidget);
      final pill = tester.getRect(find.byType(AttributionWaterfallPill));
      final notes = tester.getRect(find.byType(AttributionWaterfallNotes));
      expect(pill.bottom, lessThan(notes.top));
    });
  });

  group('the selected state', () {
    test("binds each step's written detail and caption", () {
      final data = component.read(ViewPayload.fromJson(example));
      final bitcoin = data.steps[1];
      expect(bitcoin.detail, r'+54.08% · 2.1 sh · $64,250.00');
      expect(bitcoin.selectedLabel, 'BTC selected');
      // The totals have no selected state in the contract.
      expect(data.steps.first.detail, isNull);
      expect(data.steps.last.selectedLabel, isNull);
    });

    testWidgets("shows the payload's caption where the pill was, and the "
        'detail line', (tester) async {
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 571,
            child: AttributionWaterfallCard(
              data: component.read(ViewPayload.fromJson(example)),
              initialSelectedKey: 'BTC',
            ),
          ),
        ),
      );
      expect(find.byType(AttributionWaterfallPill), findsNothing);
      expect(find.text('BTC selected'), findsOneWidget);
      expect(find.text(r'+54.08% · 2.1 sh · $64,250.00'), findsOneWidget);
      // N-4: the raw pairs behind the detail never reach the screen.
      expect(find.textContaining('0.45725'), findsNothing);
      expect(find.textContaining('90.0000'), findsNothing);
    });
  });
}
