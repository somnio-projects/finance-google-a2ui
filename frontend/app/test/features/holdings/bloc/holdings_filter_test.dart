import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/bloc/holdings_options.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// Short enough that a test does not wait, long enough to coalesce a burst.
const Duration _debounce = Duration(milliseconds: 5);

void main() {
  group('$HoldingsBloc filter', () {
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
        // A wait for something that must NOT happen cannot be an
        // `untilCalled`: it would hang until the test timed out. This
        // one stays a delay, and a too-short delay here fails safe —
        // it can only make the assertion easier to pass, never flaky.
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

    test('the new events are values', () {
      expect(const HoldingsAssetClassChanged('b').props, <Object?>['b']);
      expect(const HoldingsQueryChanged('q').props, <Object?>['q']);
      expect(const HoldingsReloaded().props, isEmpty);
    });
  });
}
