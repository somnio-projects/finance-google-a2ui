import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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

    blocTest<CatalogDetailBloc, CatalogDetailState>(
      'an envelope without the view is a contract failure on the card',
      setUp: () {
        stubCatalog(repository);
        stubViews(
          repository,
          result: Ok<RenderedViews>(envelopeOf('TaxLotTable')),
        );
      },
      build: () => buildBloc(states: const <PreviewState>[sectorState]),
      act: (bloc) => bloc.add(const CatalogDetailRequested()),
      expect: () => <dynamic>[
        const CatalogDetailState(status: CatalogDetailStatus.loading),
        isA<CatalogDetailState>().having(
          (s) => (s.renders.single.failure! as ContractFailure).path,
          'path',
          'views.$viewId',
        ),
      ],
    );

    blocTest<CatalogDetailBloc, CatalogDetailState>(
      'fails the page when the catalog fails',
      setUp: () => stubCatalog(
        repository,
        result: const Err<ViewCatalog>(TransportFailure('down')),
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const CatalogDetailRequested()),
      expect: () => <CatalogDetailState>[
        const CatalogDetailState(status: CatalogDetailStatus.loading),
        const CatalogDetailState(
          status: CatalogDetailStatus.failure,
          failure: TransportFailure('down'),
        ),
      ],
    );

    blocTest<CatalogDetailBloc, CatalogDetailState>(
      'fails the page when the backend serves no such view',
      setUp: () => stubCatalog(repository),
      build: () => buildBloc(view: 'nope.thing.v9'),
      act: (bloc) => bloc.add(const CatalogDetailRequested()),
      expect: () => <dynamic>[
        const CatalogDetailState(status: CatalogDetailStatus.loading),
        isA<CatalogDetailState>()
            .having((s) => s.status, 'status', CatalogDetailStatus.failure)
            .having(
              (s) => s.failure?.message,
              'message',
              contains('"nope.thing.v9"'),
            ),
      ],
    );
  });
}
