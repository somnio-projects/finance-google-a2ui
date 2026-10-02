part of 'catalog_bloc.dart';

/// What the index can be asked to do.
sealed class CatalogEvent extends Equatable {
  const CatalogEvent();
}

/// Load the catalog.
final class CatalogRequested extends CatalogEvent {
  /// Creates the event.
  const CatalogRequested();

  @override
  List<Object?> get props => const <Object?>[];
}
