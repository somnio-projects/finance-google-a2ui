import 'dart:convert';
import 'dart:io';

import '../architecture/workspace_sources.dart';

/// The backend's generated catalog, read from disk by the suite.
///
/// This is spec `frontend/0001` OD-1 closed. Until GGU-53 landed there was no
/// generated snapshot on `develop`, so component tests bound a **copy** of a
/// rendered example checked in under `test/` — and a copy of a generated
/// artefact is exactly the second source ADR-L D-4 argues against. The
/// snapshot exists now (`docs/catalog/view-catalog.snapshot.json`), so a test
/// reads it instead: a backend rename, a dropped field or a changed example
/// turns this suite red rather than drifting quietly.
///
/// `jsonDecode` here is fine — the ban in `binding_rules_test.dart` is on
/// `lib/`, where interpreting a server string would be an injection surface.
/// This file reads a checked-in artefact of our own build.
class CatalogSnapshot {
  const CatalogSnapshot._(this.views);

  /// Reads the snapshot, or fails loudly if the backend has not generated it.
  factory CatalogSnapshot.load() {
    final root = WorkspaceSources.locate().root.parent;
    final file = File('${root.path}/docs/catalog/view-catalog.snapshot.json');
    if (!file.existsSync()) {
      throw StateError(
        'no catalog snapshot at ${file.path} — run `cd backend && make '
        'catalog`',
      );
    }
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return CatalogSnapshot._(
      (decoded['views'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  /// Every view the backend publishes.
  final List<Map<String, dynamic>> views;

  /// The entry whose A2UI component is [component].
  ///
  /// Throws when no view claims that name, which is the failure GGU-53 went
  /// looking for: four of six component names were wrong, and a client that
  /// registered the old one would have shown a placeholder with a green gate.
  Map<String, dynamic> entryFor(String component) {
    final claimed = views.where((view) => view['component'] == component);
    if (claimed.isEmpty) {
      throw StateError(
        'no catalog view is served by "$component"; the snapshot has '
        '${views.map((v) => v['component']).join(', ')}',
      );
    }
    // Two views may legitimately share one component — `AttributionWaterfall`
    // draws both the all-time walk and the window walk (spec `backend/0039`).
    // Answering "the first one" would hand a test the wrong example and it
    // would still pass, which is the class of silent wrongness GGU-53 was
    // about. Ask by view id instead.
    if (claimed.length > 1) {
      throw StateError(
        '"$component" serves ${claimed.length} views '
        '(${claimed.map((v) => v['view']).join(', ')}); '
        'use entryForView or exampleForView with the view id you mean',
      );
    }
    return claimed.first;
  }

  /// The catalog entry of one view id, whichever component draws it.
  Map<String, dynamic> entryForView(String viewId) => views.firstWhere(
    (view) => view['view'] == viewId,
    orElse: () => throw StateError(
      'no catalog view has the id "$viewId"; the snapshot has '
      '${views.map((v) => v['view']).join(', ')}',
    ),
  );

  /// The rendered example the backend publishes for [viewId].
  Map<String, dynamic> exampleForView(String viewId) =>
      entryForView(viewId)['example']! as Map<String, dynamic>;

  /// The frozen view id [component] renders.
  String viewIdFor(String component) => exampleFor(component)['view'] as String;

  /// The rendered example the backend publishes for [component].
  Map<String, dynamic> exampleFor(String component) =>
      entryFor(component)['example']! as Map<String, dynamic>;
}
