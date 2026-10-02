part of 'catalog_bloc.dart';

/// Where the index is in its load.
enum CatalogStatus {
  /// Nothing requested yet.
  initial,

  /// The request is in flight.
  loading,

  /// The catalog is on hand.
  success,

  /// The request failed; [CatalogState.failure] says why.
  failure,
}

/// The index's state: the catalog, once it arrived.
final class CatalogState extends Equatable {
  /// Creates the state.
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.catalog,
    this.failure,
  });

  /// Where the load is.
  final CatalogStatus status;

  /// Every view the backend serves, once it answered.
  final ViewCatalog? catalog;

  /// Why the load failed, when it did.
  final AppFailure? failure;

  @override
  List<Object?> get props => <Object?>[status, catalog, failure];
}
