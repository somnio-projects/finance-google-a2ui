import 'package:finance_app/components/attribution_driver/attribution_driver_card.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tile.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tokens.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  const tiles = <DriverTile>[
    DriverTile(
      label: 'Price move',
      figure: '+4.20%',
      caption: r'+$48.56',
      trend: DriverTrend.up,
    ),
    DriverTile(label: 'Shares', figure: '90', caption: r'@ $1,204.66'),
    DriverTile(label: 'Of day gain', figure: '134.88%', caption: r'of +$3,240'),
  ];

  AttributionDriverData data(DriverTrend trend, String contribution) =>
      AttributionDriverData(
        symbol: 'NVDA',
        name: 'NVIDIA Corp',
        caption: 'Top contributor today',
        contributionDisplay: contribution,
        trend: trend,
        tiles: tiles,
      );

  Widget subject(AttributionDriverData data) => Center(
    child: SizedBox(width: 400, child: AttributionDriverCard(data: data)),
  );

  group(AttributionDriverCard, () {
    test('keeps the chrome the design was measured at', () {
      expect(AttributionDriverCard.radius, 16);
      expect(AttributionDriverCard.padding, const EdgeInsets.all(14));
    });

    testWidgets('shows every string verbatim, with the trend glyph', (
      tester,
    ) async {
      await tester.pumpApp(subject(data(DriverTrend.up, r'+$4,370.40')));
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('NVIDIA Corp'), findsOneWidget);
      expect(find.text('Top contributor today'), findsOneWidget);
      expect(find.text(r'+$4,370.40'), findsOneWidget);
      expect(find.text('Price move'), findsOneWidget);
      expect(find.text('▲ +4.20%'), findsOneWidget);
      expect(find.text(r'+$48.60'), findsNothing); // the design's, not ours
      expect(find.text(r'+$48.56'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text(r'@ $1,204.66'), findsOneWidget);
      expect(find.text('134.88%'), findsOneWidget);
      expect(find.text(r'of +$3,240'), findsOneWidget);
    });

    testWidgets('colours the contribution by its trend, light', (tester) async {
      await tester.pumpApp(subject(data(DriverTrend.up, r'+$1')));
      expect(
        tester.widget<Text>(find.text(r'+$1')).style?.color,
        homeTokensLight.gain,
      );
      expect(
        tester.widget<Text>(find.text('▲ +4.20%')).style?.color,
        homeTokensLight.gain,
      );
      // A tile with no trend keeps body text and no glyph.
      expect(
        tester.widget<Text>(find.text('90')).style?.color,
        homeTokensLight.text,
      );
    });

    testWidgets('colours a detractor with the loss mark and its glyph', (
      tester,
    ) async {
      await tester.pumpApp(subject(data(DriverTrend.down, r'-$2,295.00')));
      expect(
        tester.widget<Text>(find.text(r'-$2,295.00')).style?.color,
        homeTokensLight.loss,
      );
      expect(AttributionDriverTile.glyphFor(DriverTrend.down), '▼ ');
      expect(AttributionDriverTile.glyphFor(DriverTrend.flat), '');
      expect(
        AttributionDriverTile.figureColor(homeTokensLight, DriverTrend.flat),
        homeTokensLight.text,
      );
    });

    testWidgets('draws the measured dark surfaces under the dark theme', (
      tester,
    ) async {
      await tester.pumpApp(
        subject(data(DriverTrend.up, r'+$1')),
        brightness: Brightness.dark,
      );
      final boxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => (box.decoration as BoxDecoration).color)
          .toList();
      expect(boxes, contains(AttributionDriverTokens.dark.card));
      expect(boxes, contains(AttributionDriverTokens.dark.tile));
      expect(boxes, contains(homeTokensDark.ticker));
      expect(
        tester.widget<Text>(find.text('NVDA')).style?.color,
        homeTokensDark.tickerText,
      );
    });
  });
}
