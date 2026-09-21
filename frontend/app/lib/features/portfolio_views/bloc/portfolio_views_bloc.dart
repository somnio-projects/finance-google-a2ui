import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'portfolio_views_event.dart';
part 'portfolio_views_state.dart';

/// Fetches rendered projections for a portfolio and exposes them as state.
///
/// The bloc talks to a repository and to nothing else: it holds no HTTP, no
/// URL and no JSON. It also performs no arithmetic and no formatting — it
/// moves an envelope from the repository into state, unaltered (N-1, N-2).
class PortfolioViewsBloc
    extends Bloc<PortfolioViewsEvent, PortfolioViewsState> {
  /// Creates a bloc over [viewsRepository].
  PortfolioViewsBloc({required ViewsRepository viewsRepository})
    : _viewsRepository = viewsRepository,
      super(const PortfolioViewsState()) {
    on<PortfolioViewsRequested>(_onRequested);
  }

  final ViewsRepository _viewsRepository;

  Future<void> _onRequested(
    PortfolioViewsRequested event,
    Emitter<PortfolioViewsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: () => PortfolioViewsStatus.loading,
        failure: () => null,
      ),
    );
    final result = await _viewsRepository.fetchPortfolioViews(
      portfolioId: event.portfolioId,
      views: event.views,
      options: event.options,
    );
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => state.copyWith(
        status: () => PortfolioViewsStatus.success,
        rendered: () => value,
        failure: () => null,
      ),
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: () => PortfolioViewsStatus.failure,
        failure: () => failure,
      ),
    });
  }
}
