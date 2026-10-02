import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog_fixtures.dart';
import 'catalog_detail_bloc_harness.dart';

void main() {
  group(CatalogDetailBloc, () {
    late MockCatalogRepository repository;
    const viewId = detailViewId;

    setUp(() {
      repository = MockCatalogRepository();
    });

    CatalogDetailBloc buildBloc({
      List<PreviewState> states = const <PreviewState>[
        PreviewState.example,
        sectorState,
        undeclaredState,
      ],
      String view = viewId,
    }) => buildDetailBloc(repository, states: states, view: view);

    test('starts idle', () {
      expect(buildBloc().state, const CatalogDetailState());
      expect(const CatalogDetailRequested().props, isEmpty);
    });

    blocTest<CatalogDetailBloc, CatalogDetailState>(
      'renders the states that name declared options, alone, and refuses '
      'the one that does not',
      setUp: () {
        stubCatalog(repository);
        stubViews(
          repository,
          result: Ok<RenderedViews>(envelopeOf('HoldingsSummary')),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const CatalogDetailRequested()),
      expect: () => <dynamic>[
        const CatalogDetailState(status: CatalogDetailStatus.loading),
        isA<CatalogDetailState>()
            .having((s) => s.status, 'status', CatalogDetailStatus.success)
            .having((s) => s.entry?.id, 'entry', viewId)
            .having((s) => s.renders[0].payload, 'example render', isNull)
            .having((s) => s.renders[1].payload?.view, 'sector', viewId)
            .having((s) => s.renders[2].payload, 'undeclared', isNull)
            .having(
              (s) => (s.renders[2].failure! as ContractFailure).expected,
              'undeclared reason',
              contains('"side"'),
            ),
      ],
      verify: (_) {
        // Exactly one re-render: the example needs none, the undeclared
        // option is never sent (N-7), and the sector render travels alone.
        verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[viewId],
            options: <String, String>{'group_by': 'sector'},
          ),
        ).called(1);
        verifyNever(
          () => repository.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: any(named: 'views'),
            options: <String, String>{'side': 'sell'},
          ),
        );
      },
    );

    blocTest<CatalogDetailBloc, CatalogDetailState>(
      'records a refused re-render on its card instead of failing the page',
      setUp: () {
        stubCatalog(repository);
        stubViews(
          repository,
          result: const Err<RenderedViews>(TransportFailure('down')),
        );
      },
      build: () => buildBloc(states: const <PreviewState>[sectorState]),
      act: (bloc) => bloc.add(const CatalogDetailRequested()),
      expect: () => <dynamic>[
        const CatalogDetailState(status: CatalogDetailStatus.loading),
        isA<CatalogDetailState>()
            .having((s) => s.status, 'status', CatalogDetailStatus.success)
            .having(
              (s) => s.renders.single.failure,
              'failure',
              const TransportFailure('down'),
            ),
      ],
    );
  });
}
