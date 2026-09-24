import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/design_preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_page.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_view.dart';
import 'package:finance_app/features/catalog/view/catalog_guidance_cards.dart';
import 'package:finance_app/features/catalog/view/catalog_loading.dart';
import 'package:finance_app/features/catalog/view/catalog_preview_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_prompt_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_schema_zone.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

class _MockDetailBloc extends MockBloc<CatalogDetailEvent, CatalogDetailState>
    implements CatalogDetailBloc;

void main() {
  group(CatalogDetailView, () {
    late _MockDetailBloc bloc;
    final entry = snapshotEntry('TaxLotTable');

    setUp(() {
      bloc = _MockDetailBloc();
    });

    Future<void> pump(WidgetTester tester, {Size? size}) => tester.pumpApp(
      BlocProvider<CatalogDetailBloc>.value(
        value: bloc,
        child: const CatalogDetailView(),
      ),
      componentRegistry: buildRegistry(),
      surfaceSize: size ?? const Size(1024, 3000),
    );

    CatalogDetailState success() => CatalogDetailState(
      status: CatalogDetailStatus.success,
      entry: entry,
      renders: <PreviewRender>[
        for (final state in previewStatesFor(entry.id))
          PreviewRender(state: state),
      ],
    );

    testWidgets('draws the page in its own shape while it loads', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const CatalogDetailState());
      await pump(tester);
      // A surface, not an action (spec 0020 OD-1, AC-6).
      expect(find.byType(CatalogDetailLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the backend sentence when the page fails', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const CatalogDetailState(
          status: CatalogDetailStatus.failure,
          failure: TransportFailure('down'),
        ),
      );
      await pump(tester);
      expect(find.text('down'), findsOneWidget);
    });

    testWidgets('falls back to its own words when the failure has none', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const CatalogDetailState(status: CatalogDetailStatus.failure),
      );
      await pump(tester);
      expect(find.text('The request failed.'), findsOneWidget);
    });

    testWidgets('lays the zones side by side at the design width', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(success());
      await pump(tester);
      await tester.pumpAndSettle();
      final preview = tester.getTopLeft(find.byType(CatalogPreviewZone));
      final schema = tester.getTopLeft(find.byType(CatalogSchemaZone));
      expect(schema.dx, greaterThan(preview.dx));
      expect(find.byType(CatalogPromptZone), findsOneWidget);
      expect(find.byType(CatalogGuidanceCards), findsOneWidget);
      expect(find.text('DEFAULT · EXAMPLE PAYLOAD'), findsOneWidget);
      expect(find.text('EMPTY'), findsOneWidget);
    });

    testWidgets('stacks the zones on a narrow viewport', (tester) async {
      when(() => bloc.state).thenReturn(success());
      await pump(tester, size: const Size(600, 4000));
      await tester.pumpAndSettle();
      final preview = tester.getTopLeft(find.byType(CatalogPreviewZone));
      final schema = tester.getTopLeft(find.byType(CatalogSchemaZone));
      expect(schema.dx, preview.dx);
      expect(schema.dy, greaterThan(preview.dy));
    });
  });

  group(CatalogDetailPage, () {
    testWidgets('builds the bloc for the routed view and loads it', (
      tester,
    ) async {
      final repository = MockCatalogRepository();
      stubCatalog(repository);
      stubViews(
        repository,
        result: Ok<RenderedViews>(envelopeOf('TaxLotTable')),
      );
      await tester.pumpApp(
        const CatalogDetailPage(viewId: 'taxlots.table.v1'),
        viewsRepository: repository,
        componentRegistry: buildRegistry(),
        surfaceSize: const Size(1024, 3000),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogDetailView), findsOneWidget);
      verify(repository.fetchCatalog).called(1);
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>['taxlots.table.v1'],
          options: <String, String>{'lot_method': 'HIFO'},
        ),
      ).called(1);
    });
  });
}
