import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

/// Loads the catalog the index page draws (spec frontend/0016).
///
/// One request: `GET /v1/views`. The repository revalidates it with its
/// `ETag`, so opening the index twice costs one header the second time.
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  /// Creates the bloc over the one repository it reads.
  CatalogBloc({required ViewsRepository viewsRepository})
    : _viewsRepository = viewsRepository,
      super(const CatalogState()) {
    on<CatalogRequested>(_onRequested);
  }

  final ViewsRepository _viewsRepository;

  Future<void> _onRequested(
    CatalogRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogState(status: CatalogStatus.loading));
    final result = await _viewsRepository.fetchCatalog();
    emit(switch (result) {
      Ok<ViewCatalog>(:final value) => CatalogState(
        status: CatalogStatus.success,
        catalog: value,
      ),
      Err<ViewCatalog>(:final failure) => CatalogState(
        status: CatalogStatus.failure,
        failure: failure,
      ),
    });
  }
}
