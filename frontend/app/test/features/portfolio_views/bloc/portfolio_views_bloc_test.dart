import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(PortfolioViewsBloc, () {
    const views = <String>['holdings.allocation.v1'];
    late ViewsRepository viewsRepository;

    setUp(() {
      viewsRepository = _MockViewsRepository();
    });

    PortfolioViewsBloc buildBloc() =>
        PortfolioViewsBloc(viewsRepository: viewsRepository);

    void stubFetch(Result<RenderedViews> result) {
      when(
        () => viewsRepository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => result);
    }

    group('constructor', () {
      test('works properly', () => expect(buildBloc, returnsNormally));

      test('has correct initial state', () {
        expect(buildBloc().state, equals(const PortfolioViewsState()));
      });
    });

    group('PortfolioViewsRequested', () {
      blocTest<PortfolioViewsBloc, PortfolioViewsState>(
        'emits [loading, success] when the repository returns an envelope',
        setUp: () => stubFetch(Ok<RenderedViews>(renderedViews())),
        build: buildBloc,
        act: (bloc) => bloc.add(const PortfolioViewsRequested(views: views)),
        expect: () => <PortfolioViewsState>[
          const PortfolioViewsState(status: PortfolioViewsStatus.loading),
          PortfolioViewsState(
            status: PortfolioViewsStatus.success,
            rendered: renderedViews(),
          ),
        ],
        verify: (_) {
          verify(
            () => viewsRepository.fetchPortfolioViews(
              portfolioId: 'current',
              views: views,
            ),
          ).called(1);
        },
      );

      blocTest<PortfolioViewsBloc, PortfolioViewsState>(
        'emits [loading, failure] when the repository fails',
        setUp: () => stubFetch(
          const Err<RenderedViews>(TransportFailure('connection refused')),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const PortfolioViewsRequested(views: views)),
        expect: () => const <PortfolioViewsState>[
          PortfolioViewsState(status: PortfolioViewsStatus.loading),
          PortfolioViewsState(
            status: PortfolioViewsStatus.failure,
            failure: TransportFailure('connection refused'),
          ),
        ],
      );

      blocTest<PortfolioViewsBloc, PortfolioViewsState>(
        'passes the portfolio id and options straight through',
        setUp: () => stubFetch(Ok<RenderedViews>(renderedViews())),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const PortfolioViewsRequested(
            views: views,
            options: <String, String>{'top_n': '2'},
          ),
        ),
        verify: (_) {
          verify(
            () => viewsRepository.fetchPortfolioViews(
              portfolioId: 'current',
              views: views,
              options: const <String, String>{'top_n': '2'},
            ),
          ).called(1);
        },
      );

      blocTest<PortfolioViewsBloc, PortfolioViewsState>(
        'clears a previous failure when a new request starts',
        setUp: () => stubFetch(Ok<RenderedViews>(renderedViews())),
        build: buildBloc,
        seed: () => const PortfolioViewsState(
          status: PortfolioViewsStatus.failure,
          failure: TransportFailure('stale'),
        ),
        act: (bloc) => bloc.add(const PortfolioViewsRequested(views: views)),
        expect: () => <PortfolioViewsState>[
          const PortfolioViewsState(status: PortfolioViewsStatus.loading),
          PortfolioViewsState(
            status: PortfolioViewsStatus.success,
            rendered: renderedViews(),
          ),
        ],
      );
    });
  });
}
