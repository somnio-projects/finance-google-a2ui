import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_api_client/finance_api_client.dart'
    show decodeJsonObject;

/// The finance catalog's id (ADR-M D-5) — what this renderer advertises in
/// `a2uiRendererCapabilities` when the bundled catalog cannot be read.
const String financeCatalogId =
    'https://somniosoftware.com/a2ui/finance-showcase/v1.0/catalog.json';

/// Where the bundle carries its copy of the catalog (`make catalog`).
const String financeCatalogAsset = 'assets/a2ui/finance.catalog.json';

/// Reads the bundled catalog document [source].
///
/// Decoded by the transport's own JSON reader — the one place the binding
/// rules allow text to become data. A missing or unreadable document is not
/// a crash: it is a catalog that declares **no** component, so every surface
/// reports `VALIDATION_FAILED` on screen, which is the honest picture of a
/// renderer that cannot enforce its composition rules.
Catalog readFinanceCatalog(String? source) {
  try {
    return Catalog.fromJson(decodeJsonObject(source ?? ''));
  } on FormatException {
    return const Catalog(catalogId: financeCatalogId);
  }
}
