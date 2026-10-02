import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'catalog_detail_event.dart';
part 'catalog_detail_state.dart';

/// Loads one detail page: the view's catalog entry and its Zone 1 renders.
///
/// The entry comes from `GET /v1/views`; every state that names options is a
/// second render of the same view by the backend, requested **alone** so its
/// options travel with no other view (N-7). A state whose option the entry
/// does not declare is never requested — the catalog is the authority on
/// what may be sent, not this table.
class CatalogDetailBloc extends Bloc<CatalogDetailEvent, CatalogDetailState> {
  /// Creates the bloc for [viewId] with the design's [states].
  CatalogDetailBloc({
    required ViewsRepository viewsRepository,
    required this.viewId,
    required this.states,
  }) : _viewsRepository = viewsRepository,
       super(const CatalogDetailState()) {
    on<CatalogDetailRequested>(_onRequested);
  }

  /// The view this page documents.
  final String viewId;

  /// The Zone 1 states, in the order the page lists them.
  final List<PreviewState> states;

  /// The portfolio every re-render is asked for.
  static const String portfolioId = 'current';

  final ViewsRepository _viewsRepository;

  Future<void> _onRequested(
    CatalogDetailRequested event,
    Emitter<CatalogDetailState> emit,
  ) async {
    emit(const CatalogDetailState(status: CatalogDetailStatus.loading));
    final catalog = await _viewsRepository.fetchCatalog();
    if (catalog case Err<ViewCatalog>(:final failure)) {
      emit(_failed(failure));
      return;
    }
    final entry = (catalog as Ok<ViewCatalog>).value.entryFor(viewId);
    if (entry == null) {
      emit(_failed(ContractFailure('views[]', 'an entry for "$viewId"')));
      return;
    }
    final renders = await Future.wait(<Future<PreviewRender>>[
      for (final state in states) _render(state, entry),
    ]);
    emit(
      CatalogDetailState(
        status: CatalogDetailStatus.success,
        entry: entry,
        renders: renders,
      ),
    );
  }

  CatalogDetailState _failed(AppFailure failure) =>
      CatalogDetailState(status: CatalogDetailStatus.failure, failure: failure);

  Future<PreviewRender> _render(PreviewState state, CatalogEntry entry) async {
    if (state.options.isEmpty) return PreviewRender(state: state);
    final undeclared = state.options.keys.where((k) => !entry.declares(k));
    if (undeclared.isNotEmpty) {
      return PreviewRender(
        state: state,
        failure: ContractFailure(
          'options_schema.properties',
          'the option "${undeclared.first}" this state sends',
        ),
      );
    }
    final result = await _viewsRepository.fetchPortfolioViews(
      portfolioId: portfolioId,
      views: <String>[viewId],
      options: state.options,
    );
    return switch (result) {
      Err<RenderedViews>(:final failure) => PreviewRender(
        state: state,
        failure: failure,
      ),
      Ok<RenderedViews>(:final value) => switch (value.views[viewId]) {
        final ViewPayload payload => PreviewRender(
          state: state,
          payload: payload,
        ),
        null => PreviewRender(
          state: state,
          failure: ContractFailure('views.$viewId', 'the rendered view'),
        ),
      },
    };
  }
}
