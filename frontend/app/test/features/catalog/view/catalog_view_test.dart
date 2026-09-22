import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/features/catalog/bloc/catalog_bloc.dart';
import 'package:finance_app/features/catalog/view/catalog_card.dart';
import 'package:finance_app/features/catalog/view/catalog_header.dart';
import 'package:finance_app/features/catalog/view/catalog_legend.dart';
import 'package:finance_app/features/catalog/view/catalog_page.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/features/catalog/view/catalog_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

class _MockCatalogBloc extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc;

void main() {
  group(CatalogView, () {
    late _MockCatalogBloc bloc;

    setUp(() {
      bloc = _MockCatalogBloc();
    });

    Future<void> pump(WidgetTester tester, {ComponentRegistry? registry}) =>
        tester.pumpApp(
          BlocProvider<CatalogBloc>.value(
            value: bloc,
            child: const CatalogView(),
          ),
          componentRegistry: registry,
          surfaceSize: const Size(1024, 1400),
        );

    testWidgets('spins while the catalog loads', (tester) async {
      when(() => bloc.state)
          .thenReturn(const CatalogState(status: CatalogStatus.loading));
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the backend sentence when it fails', (tester) async {
      when(() => bloc.state).thenReturn(
        const CatalogState(
          status: CatalogStatus.failure,
          failure: TransportFailure('the server could not be reached'),
        ),
      );
      await pump(tester);
      expect(find.text('the server could not be reached'), findsOneWidget);
    });

    testWidgets('falls back to its own words when the failure has none', (
      tester,
    ) async {
      when(() => bloc.state)
          .thenReturn(const CatalogState(status: CatalogStatus.failure));
      await pump(tester);
      expect(find.text('The request failed.'), findsOneWidget);
    });

    testWidgets('draws one card per served view this build renders, and '
        'names the rest', (tester) async {
      when(() => bloc.state).thenReturn(
        CatalogState(status: CatalogStatus.success, catalog: snapshotCatalog()),
      );
      final registry = ComponentRegistry()
        ..register(const HoldingsAllocationComponent());
      await pump(tester, registry: registry);
      await tester.pumpAndSettle();
      expect(find.byType(CatalogTopBar), findsOneWidget);
      expect(find.byType(CatalogHeader), findsOneWidget);
      expect(find.byType(CatalogLegend), findsOneWidget);
      expect(find.byType(CatalogCard), findsOneWidget);
      expect(find.text('HoldingsSummary'), findsOneWidget);
      final note = tester.widget<Text>(
        find.textContaining(CatalogView.unrendered),
      );
      expect(note.data, contains('attribution.waterfall.v1'));
      expect(note.data, isNot(contains('holdings.allocation.v1')));
    });
  });

  group(CatalogPage, () {
    testWidgets('builds the bloc and asks for the catalog once', (
      tester,
    ) async {
      final repository = MockCatalogRepository();
      stubCatalog(repository);
      await tester.pumpApp(
        const CatalogPage(),
        viewsRepository: repository,
        surfaceSize: const Size(1024, 1400),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogView), findsOneWidget);
      verify(repository.fetchCatalog).called(1);
    });
  });
}
