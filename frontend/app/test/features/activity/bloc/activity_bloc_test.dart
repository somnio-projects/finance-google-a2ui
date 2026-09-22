import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(ActivityBloc, () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    ActivityBloc build() => ActivityBloc(viewsRepository: repository);

    test('copyWith keeps every field it is not handed', () {
      final initial = build().state;
      final copy = initial.copyWith(kind: 'sell');
      expect(copy.status, initial.status);
      expect(copy.kind, 'sell');
      expect(copy.timeline, initial.timeline);
      expect(copy.failure, initial.failure);
    });

    test('starts unfiltered and empty', () {
      expect(build().state, const ActivityState());
      expect(build().state.kind, 'all');
    });

    blocTest<ActivityBloc, ActivityState>(
      'loads the timeline with the filter in force',
      build: build,
      act: (bloc) => bloc.add(const ActivityRequested()),
      expect: () => <dynamic>[
        const ActivityState(status: ActivityStatus.loading),
        isA<ActivityState>()
            .having((s) => s.status, 'status', ActivityStatus.success)
            .having(
              (s) => s.timeline?.view,
              'timeline',
              ActivityBloc.timelineView,
            ),
      ],
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'all'},
        ),
      ).called(1),
    );

    blocTest<ActivityBloc, ActivityState>(
      'a chip refetches with its kind',
      build: build,
      act: (bloc) => bloc.add(const ActivityKindChanged('dividend')),
      expect: () => <dynamic>[
        const ActivityState(status: ActivityStatus.loading, kind: 'dividend'),
        isA<ActivityState>()
            .having((s) => s.kind, 'kind', 'dividend')
            .having((s) => s.status, 'status', ActivityStatus.success),
      ],
      verify: (_) => verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'dividend'},
        ),
      ).called(1),
    );

    blocTest<ActivityBloc, ActivityState>(
      'a failure is reported with its words',
      setUp: () => stubFailure(
        repository,
        ActivityBloc.timelineView,
        const TransportFailure('offline'),
      ),
      build: build,
      act: (bloc) => bloc.add(const ActivityRequested()),
      expect: () => <dynamic>[
        const ActivityState(status: ActivityStatus.loading),
        isA<ActivityState>()
            .having((s) => s.status, 'status', ActivityStatus.failure)
            .having((s) => s.failure?.message, 'message', 'offline'),
      ],
    );

    test('events are values', () {
      expect(const ActivityRequested().props, isEmpty);
      expect(const ActivityKindChanged('buy').props, <Object?>['buy']);
    });
  });
}
