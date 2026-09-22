import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/bloc/holdings_options.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// Short enough that a test does not wait, long enough to coalesce a burst.
const Duration _debounce = Duration(milliseconds: 5);

void main() {
  group('$HoldingsBloc filter and search', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    HoldingsBloc build() =>
        HoldingsBloc(viewsRepository: repository, debounce: _debounce);

    void verifyPositions(Map<String, String> options, {int times = 1}) =>
        verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: <String>[HoldingsBloc.positionsView],
            options: options,
          ),
        ).called(times);

    test('an unset filter is an absent key, not a default sent back', () {
      expect(positionsOptionsFor(everyAssetClass, ''), isEmpty);
      expect(positionsOptionsFor('bonds', ''), <String, String>{
        'asset_class': 'bonds',
      });
      expect(positionsOptionsFor(everyAssetClass, 'voo'), <String, String>{
        'query': 'voo',
      });
    });

    blocTest<HoldingsBloc, HoldingsState>(
      'a chip refetches the list with asset_class (AC-4)',
      build: build,
      act: (bloc) => bloc.add(const HoldingsAssetClassChanged('bonds')),
      verify: (_) => verifyPositions(<String, String>{'asset_class': 'bonds'}),
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'the allocation card is never refetched by a list filter (AC-3)',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const HoldingsAssetClassChanged('bonds'))
          ..add(const HoldingsQueryChanged('vanguard'));
        await Future<void>.delayed(_debounce * 4);
      },
      verify: (_) => verifyNever(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[HoldingsBloc.allocationView],
          options: any(named: 'options'),
        ),
      ),
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'a burst of keystrokes becomes one request (AC-2)',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const HoldingsQueryChanged('v'))
          ..add(const HoldingsQueryChanged('van'))
          ..add(const HoldingsQueryChanged('vanguard'));
        await Future<void>.delayed(_debounce * 4);
      },
      verify: (_) => verifyPositions(<String, String>{'query': 'vanguard'}),
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'the two compose, and clearing the box drops only the query',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const HoldingsAssetClassChanged('bonds'))
          ..add(const HoldingsQueryChanged('vanguard'));
        await Future<void>.delayed(_debounce * 4);
        bloc.add(const HoldingsQueryChanged(''));
        await Future<void>.delayed(_debounce * 4);
      },
      verify: (_) {
        verifyPositions(<String, String>{
          'asset_class': 'bonds',
          'query': 'vanguard',
        });
        verifyPositions(<String, String>{'asset_class': 'bonds'}, times: 2);
      },
    );

    blocTest<HoldingsBloc, HoldingsState>(
      'a failure on the filtered list is reported with its words',
      build: build,
      act: (bloc) {
        stubFailure(
          repository,
          HoldingsBloc.positionsView,
          const TransportFailure('offline'),
        );
        bloc.add(const HoldingsAssetClassChanged('cash'));
      },
      expect: () => <dynamic>[
        isA<HoldingsState>().having((s) => s.assetClass, 'class', 'cash'),
        isA<HoldingsState>()
            .having((s) => s.status, 'status', HoldingsStatus.failure)
            .having((s) => s.failure?.message, 'message', 'offline'),
      ],
    );

    test('a bloc closed mid-burst does not fire its timer', () async {
      final bloc = build()..add(const HoldingsQueryChanged('van'));
      await bloc.close();
      await Future<void>.delayed(_debounce * 4);

      verifyNever(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      );
    });

    test('the new events are values', () {
      expect(const HoldingsAssetClassChanged('b').props, <Object?>['b']);
      expect(const HoldingsQueryChanged('q').props, <Object?>['q']);
      expect(const HoldingsReloaded().props, isEmpty);
    });
  });
}
