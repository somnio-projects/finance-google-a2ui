part of 'catalog_detail_bloc.dart';

/// What a detail page can be asked to do.
sealed class CatalogDetailEvent extends Equatable {
  const CatalogDetailEvent();
}

/// Load the entry and every Zone 1 render.
final class CatalogDetailRequested extends CatalogDetailEvent {
  /// Creates the event.
  const CatalogDetailRequested();

  @override
  List<Object?> get props => const <Object?>[];
}
