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
    late Map<String, dynamic> allocation;

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
      allocation = snapshot.exampleFor('HoldingsSummary');
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

    test('starts with nothing loaded and the backend default range', () {
      expect(build().state, equals(const HomeState()));
      expect(build().state.range, equals('1d'));
    });

    blocTest<HomeBloc, HomeState>(
      'loads the hero and the card together',
      setUp: () {
        stub(HomeBloc.summaryView, Ok(envelope(HomeBloc.summaryView, summary)));
        stub(
          HomeBloc.allocationView,
          Ok(envelope(HomeBloc.allocationView, allocation)),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const HomeRequested()),
      expect: () => <dynamic>[
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.summary?.view, 'summary', HomeBloc.summaryView)
            .having(
              (s) => s.allocation?.view,
              'allocation',
              HomeBloc.allocationView,
            ),
      ],
      verify: (_) {
        verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[HomeBloc.allocationView],
            options: HomeBloc.allocationOptions,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'fails when either request fails, carrying that failure',
      setUp: () {
        stub(HomeBloc.summaryView, Ok(envelope(HomeBloc.summaryView, summary)));
        stub(
          HomeBloc.allocationView,
          const Err<RenderedViews>(TransportFailure('offline')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const HomeRequested()),
      expect: () => <dynamic>[
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.failure)
            .having((s) => s.failure, 'failure', isA<TransportFailure>()),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'a hero failure is reported even when the card arrived',
      setUp: () {
        stub(
          HomeBloc.summaryView,
          const Err<RenderedViews>(TransportFailure('offline')),
        );
        stub(
          HomeBloc.allocationView,
          Ok(envelope(HomeBloc.allocationView, allocation)),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const HomeRequested()),
      expect: () => <dynamic>[
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>().having((s) => s.status, 'status', HomeStatus.failure),
      ],
    );

    test('events are values', () {
      expect(const HomeRequested(), equals(const HomeRequested()));
      expect(const HomeRequested().props, isEmpty);
      expect(
        const HomeRangeChanged('1w'),
        equals(const HomeRangeChanged('1w')),
      );
      expect(
        const HomeRangeChanged('1w'),
        isNot(equals(const HomeRangeChanged('1m'))),
      );
    });
  });
}
