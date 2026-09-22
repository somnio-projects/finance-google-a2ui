import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_state_preview.dart';
import 'package:finance_app/features/conversation/view/assistant_skeleton.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

void main() {
  final holdings = snapshotEntry('HoldingsSummary');
  final waterfall = snapshotEntry('AttributionWaterfall');
  const options = PreviewState(
    label: 'x',
    kind: PreviewKind.options,
    options: <String, String>{'group_by': 'sector'},
  );

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

  group(CatalogStatePreview, () {
    testWidgets('the example renders the real component', (tester) async {
      await pump(
        tester,
        const PreviewRender(state: PreviewState.example),
        holdings,
      );
      expect(find.byType(ComponentHost), findsOneWidget);
      expect(find.byType(HoldingsAllocationCard), findsOneWidget);
    });

    testWidgets('a re-render the backend answered renders it', (tester) async {
      await pump(
        tester,
        PreviewRender(state: options, payload: holdings.example),
        holdings,
      );
      expect(find.byType(HoldingsAllocationCard), findsOneWidget);
    });

    testWidgets('a refused re-render shows the refusal verbatim', (
      tester,
    ) async {
      await pump(
        tester,
        const PreviewRender(
          state: options,
          failure: TransportFailure('the server could not be reached'),
        ),
        holdings,
      );
      expect(
        find.textContaining('the server could not be reached'),
        findsOneWidget,
      );
    });

    testWidgets('a re-render nobody requested says so', (tester) async {
      await pump(tester, const PreviewRender(state: options), holdings);
      expect(find.text('This state was not requested.'), findsOneWidget);
    });

    testWidgets('loading draws the skeleton and its sentence', (tester) async {
      await pump(
        tester,
        const PreviewRender(state: PreviewState.loading),
        holdings,
      );
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
      expect(find.text(PreviewState.loadingNote), findsOneWidget);
    });

    testWidgets('an absent state shows the note that says why', (tester) async {
      const absent = PreviewState(
        label: 'Empty',
        kind: PreviewKind.absent,
        note: 'Not drawn: no option produces it.',
      );
      await pump(tester, const PreviewRender(state: absent), holdings);
      expect(find.text(absent.note!), findsOneWidget);
      expect(find.byType(ComponentHost), findsNothing);
    });

    testWidgets('selected opens the waterfall on its first bucket', (
      tester,
    ) async {
      const selected = PreviewState(label: 's', kind: PreviewKind.selected);
      await pump(tester, const PreviewRender(state: selected), waterfall);
      final card = tester.widget<AttributionWaterfallCard>(
        find.byType(AttributionWaterfallCard),
      );
      expect(card.initialSelectedKey, card.data.steps[1].step.key);
    });
  });
}
