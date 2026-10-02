import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/catalog_entry.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';

/// The whole of `GET /v1/views`: every projection the backend can render,
/// in the order the backend lists them (N-10), with the `ETag` it was
/// served under.
class ViewCatalog extends Equatable {
  /// Creates a catalog.
  const ViewCatalog({required this.entries, required this.etag});

  /// Decodes the served list, throwing [PayloadContractException] when it is
  /// not an array of entries.
  factory ViewCatalog.fromJson(Object? json, {String? etag}) {
    if (json is! List) {
      throw const PayloadContractException(
        ContractFailure('<root>', 'an array of catalog entries'),
      );
    }
    return ViewCatalog(
      etag: etag,
      entries: <CatalogEntry>[
        for (final (index, entry) in json.indexed)
          CatalogEntry.fromJson(entry, path: 'views[$index]'),
      ],
    );
  }

  /// Every entry, in the backend's order.
  final List<CatalogEntry> entries;

  /// The strong `ETag` this catalog was served with, for revalidation.
  final String? etag;

  /// The entry for [id], or null when the backend serves no such view.
  CatalogEntry? entryFor(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[entries, etag];
}
