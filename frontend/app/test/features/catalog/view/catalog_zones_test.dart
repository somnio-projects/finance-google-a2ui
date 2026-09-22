import 'package:finance_app/features/catalog/view/catalog_detail_header.dart';
import 'package:finance_app/features/catalog/view/catalog_guidance_cards.dart';
import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/features/catalog/view/catalog_prompt_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_schema_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

void main() {
  final waterfall = snapshotEntry('AttributionWaterfall');
  final ticket = snapshotEntry('OrderTicket');

  String richText(WidgetTester tester, Finder finder) =>
      tester.widget<Text>(finder).textSpan!.toPlainText();

  group(CatalogSchemaZone, () {
    testWidgets('prints the served inventory and the declared action', (
      tester,
    ) async {
      await tester.pumpApp(
        SingleChildScrollView(child: CatalogSchemaZone(entry: waterfall)),
        surfaceSize: const Size(1024, 2400),
      );
      final text = richText(tester, find.byType(Text).last);
      expect(text, contains('component: "AttributionWaterfall"'));
      expect(text, contains('view: "attribution.waterfall.v1"'));
      for (final field in waterfall.fields) {
        expect(text, contains('${field.path}: ${field.type}'));
      }
      expect(text, contains('state: empty'));
      expect(text, contains('"drill.attribution.v1"(driver: choice)'));
      expect(text, contains('// Break this down'));
      expect(text, contains(waterfall.endpoints.first));
    });

    testWidgets('prints an empty action list as such', (tester) async {
      await tester.pumpApp(
        SingleChildScrollView(child: CatalogSchemaZone(entry: ticket)),
        surfaceSize: const Size(1024, 2400),
      );
      final text = richText(tester, find.byType(Text).last);
      expect(text, contains('actions: []'));
      expect(text, contains("input · one of 'buy', 'sell'"));
    });
  });

  group(CatalogPromptZone, () {
    testWidgets('shows the fragment the agent is taught, verbatim', (
      tester,
    ) async {
      await tester.pumpApp(
        CatalogPromptZone(entry: waterfall),
        brightness: Brightness.dark,
      );
      expect(find.text(waterfall.prompt), findsOneWidget);
      expect(
        find.text(CatalogPromptZone.injected.toUpperCase()),
        findsOneWidget,
      );
      expect(waterfall.prompt, contains('use when:'));
    });
  });

  group(CatalogGuidanceCards, () {
    testWidgets("binds the pair as Do and Don't", (tester) async {
      await tester.pumpApp(
        CatalogGuidanceCards(guidance: waterfall.guidance),
        surfaceSize: const Size(1024, 600),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data)
          .toList();
      expect(texts, contains('Do — ${waterfall.guidance!.useWhen}'));
      expect(texts, contains("Don't — ${waterfall.guidance!.avoidWhen}"));
      expect(find.text('✓'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
    });

    testWidgets('says so where the backend serves no pair', (tester) async {
      expect(ticket.guidance, isNull);
      await tester.pumpApp(CatalogGuidanceCards(guidance: ticket.guidance));
      expect(find.text(CatalogGuidanceCards.none), findsOneWidget);
      expect(find.text('✓'), findsNothing);
    });
  });

  group(CatalogDetailHeader, () {
    testWidgets('titles the page with the component and pins three pills', (
      tester,
    ) async {
      await tester.pumpApp(
        CatalogDetailHeader(entry: waterfall),
        surfaceSize: const Size(1024, 600),
      );
      expect(find.text(waterfall.component), findsNWidgets(2));
      expect(find.text(waterfall.summary), findsOneWidget);
      expect(find.text(waterfall.id), findsOneWidget);
      expect(find.text(CatalogDetailHeader.kindPill), findsOneWidget);
      expect(find.byType(CatalogPill), findsNWidgets(3));
    });
  });
}
