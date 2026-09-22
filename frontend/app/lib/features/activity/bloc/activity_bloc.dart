import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'activity_event.dart';
part 'activity_state.dart';

/// The Activity tab: the timeline, filtered by the chip the person tapped
/// (spec frontend/0009). The filter is a declared option; the backend sections
/// the rows and the client draws what arrives.
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  /// Creates the bloc over the one repository.
  ActivityBloc({required ViewsRepository viewsRepository})
    : _views = viewsRepository,
      super(const ActivityState()) {
    on<ActivityRequested>((event, emit) => _load(state.kind, emit));
    on<ActivityKindChanged>((event, emit) => _load(event.kind, emit));
  }

  /// The timeline's view id — a literal, as N-6 asks.
  static const String timelineView = 'activity.timeline.v1';

  final ViewsRepository _views;

  Future<void> _load(String kind, Emitter<ActivityState> emit) async {
    emit(
      state.copyWith(
        status: ActivityStatus.loading,
        kind: kind,
        failure: () => null,
      ),
    );
    final result = await _views.fetchPortfolioViews(
      portfolioId: 'current',
      views: <String>[timelineView],
      options: <String, String>{'kind': kind},
    );
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        status: ActivityStatus.success,
        timeline: () => value.views[timelineView],
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: ActivityStatus.failure,
        failure: () => failure,
      ),
    });
  }
}
