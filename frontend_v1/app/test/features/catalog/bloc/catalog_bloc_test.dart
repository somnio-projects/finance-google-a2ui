import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/catalog/bloc/catalog_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog_fixtures.dart';

void main() {
  group(CatalogBloc, () {
    late MockCatalogRepository repository;

    setUp(() {
      repository = MockCatalogRepository();
    });

    CatalogBloc buildBloc() => CatalogBloc(viewsRepository: repository);

    test('starts idle with nothing loaded', () {
      expect(buildBloc().state, const CatalogState());
      expect(const CatalogRequested().props, isEmpty);
    });

    blocTest<CatalogBloc, CatalogState>(
      'loads the catalog the backend serves',
      setUp: () => stubCatalog(repository),
      build: buildBloc,
      act: (bloc) => bloc.add(const CatalogRequested()),
      expect: () => <CatalogState>[
        const CatalogState(status: CatalogStatus.loading),
        CatalogState(status: CatalogStatus.success, catalog: snapshotCatalog()),
      ],
      verify: (_) => verify(repository.fetchCatalog).called(1),
    );

    blocTest<CatalogBloc, CatalogState>(
      'reports the failure and its code',
      setUp: () => stubCatalog(
        repository,
        result: const Err<ViewCatalog>(TransportFailure('unreachable')),
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const CatalogRequested()),
      expect: () => <CatalogState>[
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(
          status: CatalogStatus.failure,
          failure: TransportFailure('unreachable'),
        ),
      ],
    );
  });
}
