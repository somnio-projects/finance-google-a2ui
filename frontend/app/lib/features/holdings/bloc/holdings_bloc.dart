import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/features/holdings/bloc/holdings_options.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'holdings_event.dart';
part 'holdings_state.dart';

/// The Holdings tab: the position list and the allocation card, grouped as
/// the toggle asks and scoped as the sheet and the search box ask
/// (spec frontend/0009, frontend/0018).
///
/// `asset_class` and `query` are options of `holdings.positions.v1` **only**,
/// so they ride a positions-only request: the read endpoint applies one flat
/// option set to every view it is given, and the allocation card does not
/// declare either, so sending them together would 422 the lot (N-7).
class HoldingsBloc extends Bloc<HoldingsEvent, HoldingsState> {
  /// Creates the bloc over the one repository.
  ///
  /// [debounce] is injected so a test drives it explicitly.
  HoldingsBloc({
    required ViewsRepository viewsRepository,
    this.debounce = defaultDebounce,
  }) : _views = viewsRepository,
       super(const HoldingsState()) {
    on<HoldingsRequested>(_onRequested);
    on<HoldingsGroupByChanged>(_onGroupByChanged);
    on<HoldingsListChanged>(
      (event, emit) => emit(state.copyWith(list: event.list)),
    );
    on<HoldingsAssetClassChanged>(_onAssetClassChanged);
    on<HoldingsQueryChanged>(_onQueryChanged);
    on<HoldingsReloaded>((event, emit) => _reloadPositions(emit));
  }

  /// The list's view id — a literal, as N-6 asks.
  static const String positionsView = 'holdings.positions.v1';

  /// The card's view id.
  static const String allocationView = 'holdings.allocation.v1';

  /// How long a burst of keystrokes coalesces before one request goes out.
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// The debounce in effect.
  final Duration debounce;

  final ViewsRepository _views;
  Timer? _timer;
  Map<String, String>? _inFlight;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    HoldingsRequested event,
    Emitter<HoldingsState> emit,
  ) async {
    emit(state.copyWith(status: HoldingsStatus.loading, failure: () => null));
    final results = await Future.wait(<Future<Result<RenderedViews>>>[
      _fetch(positionsView, positionsOptionsFor(state.assetClass, state.query)),
      _fetch(allocationView, allocationOptionsFor(state.groupBy)),
    ]);
    final failure = results[0].failureOrNull ?? results[1].failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(status: HoldingsStatus.failure, failure: () => failure),
      );
      return;
    }
    emit(
      state.copyWith(
        status: HoldingsStatus.success,
        positions: () => results[0].valueOrNull!.views[positionsView],
        allocation: () => results[1].valueOrNull!.views[allocationView],
      ),
    );
  }

  Future<void> _onGroupByChanged(
    HoldingsGroupByChanged event,
    Emitter<HoldingsState> emit,
  ) async {
    emit(state.copyWith(groupBy: event.groupBy));
    final result = await _fetch(
      allocationView,
      allocationOptionsFor(event.groupBy),
    );
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        allocation: () => value.views[allocationView],
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: HoldingsStatus.failure,
        failure: () => failure,
      ),
    });
  }

  Future<void> _onAssetClassChanged(
    HoldingsAssetClassChanged event,
    Emitter<HoldingsState> emit,
  ) {
    emit(state.copyWith(assetClass: event.assetClass));
    return _reloadPositions(emit);
  }

  /// A keystroke: record it, then reload once the burst stops.
  void _onQueryChanged(
    HoldingsQueryChanged event,
    Emitter<HoldingsState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (!isClosed) add(const HoldingsReloaded());
    });
  }

  Future<void> _reloadPositions(Emitter<HoldingsState> emit) async {
    final options = positionsOptionsFor(state.assetClass, state.query);
    _inFlight = options;
    final result = await _fetch(positionsView, options);
    if (!identical(_inFlight, options)) return;
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        positions: () => value.views[positionsView],
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: HoldingsStatus.failure,
        failure: () => failure,
      ),
    });
  }

  Future<Result<RenderedViews>> _fetch(
    String view,
    Map<String, String> options,
  ) => _views.fetchPortfolioViews(
    portfolioId: 'current',
    views: <String>[view],
    options: options,
  );
}
