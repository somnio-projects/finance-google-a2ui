/// The Holdings search box: the debounce, how it composes with the chip, and
/// what happens when a bloc is closed mid-burst.
///
/// Split out of `holdings_filter_test.dart` when that file passed the 150-line
/// budget. The seam is the one `activity_*_test.dart` already draws: a chip is
/// a single event, a search box is a stream of them.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// Short enough that a test does not wait, long enough to coalesce a burst.
const Duration _debounce = Duration(milliseconds: 5);

void main() {
  group('$HoldingsBloc search', () {
    late ViewsRepository repository;
    late List<Map<String, String>> calls;

    setUp(() {
      repository = _MockViewsRepository();
      calls = <Map<String, String>>[];
      stubView(
        repository,
        HoldingsBloc.positionsView,
        'PositionList',
        onCall: calls.add,
      );
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

    blocTest<HoldingsBloc, HoldingsState>(
      'a burst of keystrokes becomes one request (AC-2)',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const HoldingsQueryChanged('v'))
          ..add(const HoldingsQueryChanged('van'))
          ..add(const HoldingsQueryChanged('vanguard'));
        await awaitRequest(calls, <String, String>{'query': 'vanguard'});
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
        await awaitRequest(calls, <String, String>{
          'asset_class': 'bonds',
          'query': 'vanguard',
        });
        bloc.add(const HoldingsQueryChanged(''));
        // The second time this exact request is made: the chip fired it once
        // already, so "it happened" is not enough to tell the two apart.
        await awaitRequest(calls, <String, String>{
          'asset_class': 'bonds',
        }, times: 2);
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
      // A wait for something that must NOT happen cannot be an
      // `untilCalled`: it would hang until the test timed out. This
      // one stays a delay, and a too-short delay here fails safe —
      // it can only make the assertion easier to pass, never flaky.
      await Future<void>.delayed(_debounce * 4);

      verifyNever(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      );
    });
  });
}
