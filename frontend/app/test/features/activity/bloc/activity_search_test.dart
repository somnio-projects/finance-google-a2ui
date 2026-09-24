import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// Short enough that a test does not wait, long enough to coalesce a burst.
const Duration _debounce = Duration(milliseconds: 5);

void main() {
  group('$ActivityBloc search', () {
    late ViewsRepository repository;
    late List<Map<String, String>> calls;

    setUp(() {
      repository = _MockViewsRepository();
      calls = <Map<String, String>>[];
      stubView(
        repository,
        ActivityBloc.timelineView,
        'ActivityTimeline',
        onCall: calls.add,
      );
    });

    ActivityBloc build() =>
        ActivityBloc(viewsRepository: repository, debounce: _debounce);

    blocTest<ActivityBloc, ActivityState>(
      'a burst of keystrokes becomes one request (AC-2)',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const ActivityQueryChanged('n'))
          ..add(const ActivityQueryChanged('nv'))
          ..add(const ActivityQueryChanged('nvda'));
        await awaitRequest(calls, <String, String>{
          'kind': 'all',
          'query': 'nvda',
        });
      },
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'all', 'query': 'nvda'},
        ),
      ).called(1),
    );

    blocTest<ActivityBloc, ActivityState>(
      'the search rides beside the chip, not instead of it',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const ActivityKindChanged('sell'))
          ..add(const ActivityQueryChanged('voo'));
        await awaitRequest(calls, <String, String>{
          'kind': 'sell',
          'query': 'voo',
        });
      },
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'sell', 'query': 'voo'},
        ),
      ).called(1),
    );

    blocTest<ActivityBloc, ActivityState>(
      'clearing the box sends no query at all (AC-5)',
      build: build,
      act: (bloc) async {
        bloc.add(const ActivityQueryChanged('nvda'));
        await awaitRequest(calls, <String, String>{
          'kind': 'all',
          'query': 'nvda',
        });
        bloc.add(const ActivityQueryChanged(''));
        await awaitRequest(calls, <String, String>{'kind': 'all'});
      },
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'all'},
        ),
      ).called(1),
    );

    blocTest<ActivityBloc, ActivityState>(
      'a query that is still being typed never reaches the network',
      build: build,
      act: (bloc) => bloc.add(const ActivityQueryChanged('nv')),
      expect: () => <dynamic>[
        isA<ActivityState>()
            .having((s) => s.query, 'query', 'nv')
            .having((s) => s.status, 'status', ActivityStatus.initial),
      ],
      verify: (_) => verifyNever(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ),
    );

    test('a bloc closed mid-burst does not fire its timer', () async {
      final bloc = build()..add(const ActivityQueryChanged('nv'));
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

    test('the new events are values', () {
      expect(const ActivityQueryChanged('a').props, <Object?>['a']);
      expect(const ActivityReloaded().props, isEmpty);
    });
  });
}
