import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'holdings_event.dart';
part 'holdings_state.dart';

/// The Holdings tab: the position list and the allocation card, grouped as
/// the toggle asks (spec frontend/0009).
class HoldingsBloc extends Bloc<HoldingsEvent, HoldingsState> {
  /// Creates the bloc over the one repository.
  HoldingsBloc({required ViewsRepository viewsRepository})
    : _views = viewsRepository,
      super(const HoldingsState()) {
    on<HoldingsRequested>(_onRequested);
    on<HoldingsGroupByChanged>(_onGroupByChanged);
    on<HoldingsListChanged>(
      (event, emit) => emit(state.copyWith(list: event.list)),
    );
  }

  /// The list's view id — a literal, as N-6 asks.
  static const String positionsView = 'holdings.positions.v1';

  /// The card's view id.
  static const String allocationView = 'holdings.allocation.v1';

  final ViewsRepository _views;

  /// The card's declared options for [groupBy]: whole dollars, no headline.
  static Map<String, String> allocationOptions(String groupBy) =>
      <String, String>{
        'group_by': groupBy,
        'precision': '0',
        'headline': 'false',
      };

  Future<void> _onRequested(
    HoldingsRequested event,
    Emitter<HoldingsState> emit,
  ) async {
    emit(state.copyWith(status: HoldingsStatus.loading, failure: () => null));
    final results = await Future.wait(<Future<Result<RenderedViews>>>[
      _fetch(positionsView, const <String, String>{}),
      _fetch(allocationView, allocationOptions(state.groupBy)),
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
    // The card's figures belong to the *old* grouping until the answer lands,
    // so the view is told to grey them rather than show them under the pill
    // the person just tapped (spec frontend/0020 OD-3).
    emit(state.copyWith(groupBy: event.groupBy, allocationLoading: true));
    final result = await _fetch(
      allocationView,
      allocationOptions(event.groupBy),
    );
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        allocationLoading: false,
        allocation: () => value.views[allocationView],
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: HoldingsStatus.failure,
        allocationLoading: false,
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
