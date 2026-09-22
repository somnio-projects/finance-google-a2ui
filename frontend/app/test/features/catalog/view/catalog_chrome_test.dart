import 'package:finance_app/features/catalog/view/catalog_header.dart';
import 'package:finance_app/features/catalog/view/catalog_legend.dart';
import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/features/catalog/view/catalog_zone_label.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/catalog_palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(CatalogHeader, () {
    testWidgets('says its words and wears the two honest pills', (
      tester,
    ) async {
      await tester.pumpApp(const CatalogHeader(), brightness: Brightness.dark);
      expect(find.text(CatalogHeader.eyebrow), findsOneWidget);
      expect(find.text(CatalogHeader.title), findsOneWidget);
      expect(find.text(CatalogHeader.lede), findsOneWidget);
      expect(find.byType(CatalogPill), findsNWidgets(2));
      expect(find.text('A2UI v1.0'), findsNothing);
    });
  });

  group(CatalogLegend, () {
    testWidgets('names the four semantics and the simulation mark', (
      tester,
    ) async {
      await tester.pumpApp(const CatalogLegend());
      for (final word in <String>['Gain', 'Loss', 'Short-term', 'Long-term']) {
        expect(find.text(word), findsOneWidget);
      }
      expect(find.text('▲'), findsOneWidget);
      expect(find.text('▼'), findsOneWidget);
      expect(find.text(CatalogLegend.simulated), findsOneWidget);
    });
  });

  group(CatalogTopBar, () {
    testWidgets('shows the fixed crumb on the index', (tester) async {
      await tester.pumpApp(const CatalogTopBar());
      expect(find.text(CatalogTopBar.title), findsOneWidget);
      expect(
        find.text(CatalogTopBar.crumb, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('names the component on a detail page and goes back', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/catalog/x.y.v1',
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.catalog,
            builder: (context, state) => const Text('index'),
          ),
          GoRoute(
            path: AppRoutes.catalogDetail,
            builder: (context, state) =>
                const Scaffold(body: CatalogTopBar(component: 'TaxLotTable')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      expect(
        find.text('${CatalogTopBar.crumb} / TaxLotTable', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(
        find.text('${CatalogTopBar.crumb} / TaxLotTable', findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('index'), findsOneWidget);
    });
  });

  group(CatalogZoneLabel, () {
    testWidgets('upper-cases the label and marks Zone 1 as simulated', (
      tester,
    ) async {
      await tester.pumpApp(
        const CatalogZoneLabel('Zone 1 · Live preview', simulated: true),
      );
      expect(find.text('ZONE 1 · LIVE PREVIEW'), findsOneWidget);
      expect(find.text(CatalogZoneLabel.simulatedLabel), findsOneWidget);
    });

    testWidgets('leaves the mark off the other zones', (tester) async {
      await tester.pumpApp(const CatalogZoneLabel('Zone 2 · A2UI schema'));
      expect(find.text(CatalogZoneLabel.simulatedLabel), findsNothing);
    });
  });

  group(CatalogStateCard, () {
    testWidgets('captions its child', (tester) async {
      await tester.pumpApp(
        const CatalogStateCard(label: 'Default', child: Text('body')),
      );
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group(CatalogPill, () {
    testWidgets('the component pill is the teal one', (tester) async {
      await tester.pumpApp(
        const Row(
          children: <Widget>[CatalogPill('a'), CatalogPill.component('b')],
        ),
      );
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(boxes, <Color>[
        catalogTokensLight.pill,
        catalogTokensLight.componentPill,
      ]);
    });
  });
}
