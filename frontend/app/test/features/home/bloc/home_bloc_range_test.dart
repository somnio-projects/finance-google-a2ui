import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/home/bloc/home_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/catalog_snapshot.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(HomeBloc, () {
    late ViewsRepository repository;
    late Map<String, dynamic> summary;

    RenderedViews envelope(String view, Map<String, dynamic> example) =>
        RenderedViews.fromJson(<String, dynamic>{
          'as_of': '2026-01-15T12:00:00Z',
          'portfolio_id': 'current',
          'views': <String, dynamic>{view: example},
        });

    setUp(() {
      repository = _MockViewsRepository();
      final snapshot = CatalogSnapshot.load();
      summary = snapshot.exampleFor('PortfolioSummary');
    });

    void stub(String view, Result<RenderedViews> result) {
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[view],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => result);
    }

    HomeBloc build() => HomeBloc(viewsRepository: repository);

    blocTest<HomeBloc, HomeState>(
      'a new range refetches the hero alone with that range',
      setUp: () => stub(
        HomeBloc.summaryView,
        Ok(envelope(HomeBloc.summaryView, summary)),
      ),
      build: build,
      act: (bloc) => bloc.add(const HomeRangeChanged('1w')),
      expect: () => <dynamic>[
        // In flight: the hero says it is loading (spec 0015 OD-1).
        const HomeState(range: '1w', status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.range, 'range', '1w')
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.summary, 'summary', isNotNull),
      ],
      verify: (_) {
        verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[HomeBloc.summaryView],
            options: <String, String>{'range': '1w'},
          ),
        ).called(1);
        verifyNever(
          () => repository.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: <String>[HomeBloc.allocationView],
            options: any(named: 'options'),
          ),
        );
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a failed range refetch is reported',
      setUp: () => stub(
        HomeBloc.summaryView,
        const Err<RenderedViews>(TransportFailure('offline')),
      ),
      build: build,
      act: (bloc) => bloc.add(const HomeRangeChanged('1y')),
      expect: () => <dynamic>[
        const HomeState(range: '1y', status: HomeStatus.loading),
        isA<HomeState>().having((s) => s.status, 'status', HomeStatus.failure),
      ],
    );
  });
}
