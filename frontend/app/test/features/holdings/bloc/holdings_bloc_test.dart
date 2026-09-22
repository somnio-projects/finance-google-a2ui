import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(HoldingsBloc, () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    HoldingsBloc build() => HoldingsBloc(viewsRepository: repository);

    test('starts with the class grouping and the position list', () {
      expect(build().state, const HoldingsState());
      expect(build().state.groupBy, 'asset_class');
      expect(build().state.list, HoldingsList.positions);
    });

    blocTest<HoldingsBloc, HoldingsState>(
      'loads both views, the card grouped by class without a headline',
      build: build,
      act: (bloc) => bloc.add(const HoldingsRequested()),
      expect: () => <dynamic>[
        const HoldingsState(status: HoldingsStatus.loading),
        isA<HoldingsState>()
            .having((s) => s.status, 'status', HoldingsStatus.success)
            .having(
              (s) => s.positions?.view,
              'positions',
              HoldingsBloc.positionsView,
            )
            .having(
              (s) => s.allocation?.view,
              'allocation',
              HoldingsBloc.allocationView,
            ),
      ],
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.allocationView],
          options: HoldingsBloc.allocationOptions('asset_class'),
        ),
      ).called(1),
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'a failed view fails the tab',
      setUp: () => stubFailure(
        repository,
        HoldingsBloc.positionsView,
        const TransportFailure('offline'),
      ),
      build: build,
      act: (bloc) => bloc.add(const HoldingsRequested()),
      expect: () => <dynamic>[
        const HoldingsState(status: HoldingsStatus.loading),
        isA<HoldingsState>()
            .having((s) => s.status, 'status', HoldingsStatus.failure)
            .having((s) => s.failure?.message, 'message', 'offline'),
      ],
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'the toggle refetches the card alone, by sector',
      build: build,
      act: (bloc) => bloc.add(const HoldingsGroupByChanged('sector')),
      expect: () => <dynamic>[
        const HoldingsState(groupBy: 'sector'),
        isA<HoldingsState>()
            .having((s) => s.groupBy, 'groupBy', 'sector')
            .having((s) => s.allocation, 'allocation', isNotNull),
      ],
      verify: (_) {
        verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[HoldingsBloc.allocationView],
            options: HoldingsBloc.allocationOptions('sector'),
          ),
        ).called(1);
        verifyNever(
          () => repository.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: <String>[HoldingsBloc.positionsView],
            options: any(named: 'options'),
          ),
        );
      },
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'a failed toggle is reported',
      setUp: () => stubFailure(
        repository,
        HoldingsBloc.allocationView,
        const TransportFailure('offline'),
      ),
      build: build,
      act: (bloc) => bloc.add(const HoldingsGroupByChanged('sector')),
      expect: () => <dynamic>[
        const HoldingsState(groupBy: 'sector'),
        isA<HoldingsState>().having(
          (s) => s.status,
          'status',
          HoldingsStatus.failure,
        ),
      ],
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'the segment switches the list without a request',
      build: build,
      act: (bloc) => bloc.add(const HoldingsListChanged(HoldingsList.classes)),
      expect: () => const <HoldingsState>[
        HoldingsState(list: HoldingsList.classes),
      ],
      verify: (_) => verifyNever(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ),
    );

    test('events are values', () {
      expect(const HoldingsRequested().props, isEmpty);
      expect(const HoldingsGroupByChanged('sector').props, <Object?>['sector']);
      expect(const HoldingsListChanged(HoldingsList.classes).props, <Object?>[
        HoldingsList.classes,
      ]);
    });
  });
}
