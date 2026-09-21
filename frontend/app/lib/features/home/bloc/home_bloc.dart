import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Loads the two views the Home tab draws (spec 0026).
///
/// `portfolio.summary.v1` is the hero and everything around it;
/// `holdings.allocation.v1` grouped by asset class is the card. They are two
/// requests rather than one because the read endpoint applies one flat option
/// set to every view it renders, and the card wants whole dollars where the
/// hero wants cents. Changing the range refetches the hero alone.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  /// Creates the bloc over the one repository it reads.
  HomeBloc({required ViewsRepository viewsRepository})
    : _viewsRepository = viewsRepository,
      super(const HomeState()) {
    on<HomeRequested>(_onRequested);
    on<HomeRangeChanged>(_onRangeChanged);
  }

  /// The hero's view id — a literal, as N-6 asks.
  static const String summaryView = 'portfolio.summary.v1';

  /// The card's view id.
  static const String allocationView = 'holdings.allocation.v1';

  /// The card's declared options: by class, whole dollars, no headline.
  static const Map<String, String> allocationOptions = <String, String>{
    'group_by': 'asset_class',
    'precision': '0',
    'headline': 'false',
  };

  final ViewsRepository _viewsRepository;

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: () => HomeStatus.loading, failure: () => null));
    final results = await Future.wait(<Future<Result<RenderedViews>>>[
      _fetch(summaryView, <String, String>{'range': state.range}),
      _fetch(allocationView, allocationOptions),
    ]);
    emit(_merge(results[0], results[1]));
  }

  Future<void> _onRangeChanged(
    HomeRangeChanged event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(range: () => event.range));
    final result = await _fetch(summaryView, <String, String>{
      'range': event.range,
    });
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        summary: () => value.views[summaryView],
        failure: () => null,
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: () => HomeStatus.failure,
        failure: () => failure,
      ),
    });
  }

  Future<Result<RenderedViews>> _fetch(
    String view,
    Map<String, String> options,
  ) => _viewsRepository.fetchPortfolioViews(
    portfolioId: 'current',
    views: <String>[view],
    options: options,
  );

  HomeState _merge(Result<RenderedViews> hero, Result<RenderedViews> card) {
    final failure = switch ((hero, card)) {
      (Err<RenderedViews>(:final failure), _) => failure,
      (_, Err<RenderedViews>(:final failure)) => failure,
      _ => null,
    };
    if (failure != null) {
      return state.copyWith(
        status: () => HomeStatus.failure,
        failure: () => failure,
      );
    }
    final heroViews = (hero as Ok<RenderedViews>).value.views;
    final cardViews = (card as Ok<RenderedViews>).value.views;
    return state.copyWith(
      status: () => HomeStatus.success,
      summary: () => heroViews[summaryView],
      allocation: () => cardViews[allocationView],
      failure: () => null,
    );
  }
}
