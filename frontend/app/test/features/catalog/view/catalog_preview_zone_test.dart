import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_preview_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_zone_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

const PreviewState _absent = PreviewState(
  label: 'Empty',
  kind: PreviewKind.absent,
  note: 'Not drawn.',
);

void main() {
  group(CatalogPreviewZone, () {
    final entry = snapshotEntry('ScenarioComparison');

    Future<void> pump(WidgetTester tester, List<PreviewState> states) =>
        tester.pumpApp(
          Scaffold(
            body: SingleChildScrollView(
              child: CatalogPreviewZone(
                entry: entry,
                renders: <PreviewRender>[
                  for (final state in states) PreviewRender(state: state),
                ],
              ),
            ),
          ),
          componentRegistry: buildRegistry(),
          surfaceSize: const Size(1024, 2400),
        );

    testWidgets('a live card takes the column; two notes share a row', (
      tester,
    ) async {
      await pump(tester, const <PreviewState>[
        PreviewState.example,
        _absent,
        PreviewState.loading,
      ]);
      final cards = find.byType(CatalogStateCard);
      expect(cards, findsNWidgets(3));
      final example = tester.getRect(cards.at(0));
      final absent = tester.getRect(cards.at(1));
      final loading = tester.getRect(cards.at(2));
      expect(example.width, greaterThan(absent.width * 1.9));
      expect(absent.top, loading.top);
      expect(loading.left, greaterThan(absent.right));
    });

    testWidgets("an odd note keeps the pair's width, alone", (tester) async {
      await pump(tester, const <PreviewState>[PreviewState.example, _absent]);
      final cards = find.byType(CatalogStateCard);
      final example = tester.getRect(cards.at(0));
      final absent = tester.getRect(cards.at(1));
      expect(absent.width, lessThan(example.width / 1.9));
      expect(find.text(CatalogZoneLabel.simulatedLabel), findsOneWidget);
    });
  });
}
