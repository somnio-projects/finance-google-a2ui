import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'activity_event.dart';
part 'activity_state.dart';

/// The Activity tab: the timeline, scoped by the chip that was tapped and
/// the text that was typed (spec frontend/0009, frontend/0018).
///
/// Both are **declared options**. This bloc filters nothing: it sends
/// `kind` and `query` and renders the rows that come back, in the order
/// they arrived (N-10).
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  /// Creates the bloc over the one repository.
  ///
  /// [debounce] is injected so a test drives it explicitly instead of
  /// sleeping for a constant someone has to keep in step.
  ActivityBloc({
    required ViewsRepository viewsRepository,
    this.debounce = defaultDebounce,
  }) : _views = viewsRepository,
       super(const ActivityState()) {
    on<ActivityRequested>((event, emit) => _load(emit));
    on<ActivityKindChanged>(_onKindChanged);
    on<ActivityQueryChanged>(_onQueryChanged);
    on<ActivityReloaded>((event, emit) => _load(emit));
  }

  /// The timeline's view id — a literal, as N-6 asks.
  static const String timelineView = 'activity.timeline.v1';

  /// How long a burst of keystrokes coalesces before one request goes out.
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// The debounce in effect.
  final Duration debounce;

  final ViewsRepository _views;
  Timer? _timer;

  /// The exact options map of the request in flight, compared by identity
  /// when a response lands so a slow answer to `nv` cannot overwrite the
  /// answer to `nvda` (spec frontend/0018 OD-4).
  Map<String, String>? _inFlight;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onKindChanged(
    ActivityKindChanged event,
    Emitter<ActivityState> emit,
  ) {
    emit(
      state.copyWith(
        kind: event.kind,
        status: ActivityStatus.loading,
        failure: () => null,
      ),
    );
    return _fetch(emit);
  }

  /// A keystroke: record it, then reload once the burst stops.
  void _onQueryChanged(
    ActivityQueryChanged event,
    Emitter<ActivityState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (!isClosed) add(const ActivityReloaded());
    });
  }

  Future<void> _load(Emitter<ActivityState> emit) {
    emit(state.copyWith(status: ActivityStatus.loading, failure: () => null));
    return _fetch(emit);
  }

  Future<void> _fetch(Emitter<ActivityState> emit) async {
    final options = <String, String>{
      'kind': state.kind,
      if (state.query.isNotEmpty) 'query': state.query,
    };
    _inFlight = options;
    final result = await _views.fetchPortfolioViews(
      portfolioId: 'current',
      views: <String>[timelineView],
      options: options,
    );
    if (!identical(_inFlight, options)) return;
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
