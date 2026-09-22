import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_state_preview.dart';
import 'package:finance_app/features/catalog/view/catalog_state_special.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

void main() {
  final ticket = snapshotEntry('OrderTicket');

  Future<void> pump(
    WidgetTester tester,
    PreviewRender render,
    CatalogEntry e,
  ) => tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(
        child: CatalogStatePreview(render: render, entry: e),
      ),
    ),
    componentRegistry: buildRegistry(),
    surfaceSize: const Size(600, 1600),
  );

  group(RecomputedTicketPreview, () {
    testWidgets('recomputed marks the figures the backend changed', (
      tester,
    ) async {
      const recomputed = PreviewState(
        label: 'r',
        kind: PreviewKind.recomputed,
        options: <String, String>{'size': '2'},
      );
      final after = ViewPayload.fromJson(
        orderTicketExampleWithNotional(r'$99.00'),
      );
      await pump(
        tester,
        PreviewRender(state: recomputed, payload: after),
        ticket,
      );
      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.changedFigures, <String>{'notional'});
      expect(find.text(r'$99.00'), findsOneWidget);
    });
  });

  group(SelectedWaterfallPreview, () {
    testWidgets('selects nothing when the backend sent no buckets', (
      tester,
    ) async {
      final example = CatalogSnapshot.load().exampleFor('AttributionWaterfall');
      final empty = ViewPayload.fromJson(<String, dynamic>{
        ...example,
        'buckets': const <Object?>[],
      });
      await tester.pumpApp(SelectedWaterfallPreview(payload: empty));
      final card = tester.widget<AttributionWaterfallCard>(
        find.byType(AttributionWaterfallCard),
      );
      expect(card.initialSelectedKey, isNull);
    });
  });
}
