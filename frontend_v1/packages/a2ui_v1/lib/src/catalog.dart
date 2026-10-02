import 'package:equatable/equatable.dart';

/// One component's composition constraints (`catalog_definition.json`,
/// `ComponentDefinition`). `null` means *omitted*, which the spec defines as
/// "all allowed" — not the same as an empty list, which allows none.
final class CompositionRules extends Equatable {
  /// Creates the rules.
  const CompositionRules({this.allowedParents, this.allowedChildren});

  /// The parent types this component may sit under, or `null` for any.
  final List<String>? allowedParents;

  /// The child types this component may hold, or `null` for any.
  final List<String>? allowedChildren;

  /// Whether this component may sit under a [parent].
  bool acceptsParent(String parent) =>
      allowedParents == null || allowedParents!.contains(parent);

  /// Whether this component may hold a [child].
  bool acceptsChild(String child) =>
      allowedChildren == null || allowedChildren!.contains(child);

  @override
  List<Object?> get props => <Object?>[allowedParents, allowedChildren];
}

/// The parts of a catalog document the renderer enforces.
///
/// Read from the **generated** `docs/a2ui/v1.0/finance.catalog.json`
/// (ADR-M D-5). Only names and composition rules are read; the JSON
/// Schemas of each component's properties are the agent's business (it
/// validates what it emits, spec `backend/0053` AC-1).
final class Catalog extends Equatable {
  /// Creates the catalog.
  const Catalog({
    required this.catalogId,
    this.components = const <String, CompositionRules>{},
    this.functions = const <String>{},
  });

  /// Reads a catalog document. Throws [FormatException] when it carries no
  /// `catalogId`, or a component entry is not an object.
  factory Catalog.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['catalogId'] is! String) {
      throw const FormatException('a catalog document needs a catalogId');
    }
    final components = json['components'];
    final functions = json['functions'];
    return Catalog(
      catalogId: json['catalogId']! as String,
      components: <String, CompositionRules>{
        if (components is Map<String, Object?>)
          for (final entry in components.entries)
            entry.key: _rules(entry.key, entry.value),
      },
      functions: <String>{
        if (functions is Map<String, Object?>) ...functions.keys,
      },
    );
  }

  /// The id surfaces name in `catalogId`.
  final String catalogId;

  /// Every component type the catalog declares, with its rules.
  final Map<String, CompositionRules> components;

  /// Every function the catalog declares, e.g. `renderView`.
  final Set<String> functions;

  @override
  List<Object?> get props => <Object?>[catalogId, components, functions];
}

CompositionRules _rules(String name, Object? json) {
  if (json is! Map<String, Object?>) {
    throw FormatException('component "$name" is not an object');
  }
  return CompositionRules(
    allowedParents: _names(json['allowedParents']),
    allowedChildren: _names(json['allowedChildren']),
  );
}

List<String>? _names(Object? json) =>
    json is List<Object?> ? json.whereType<String>().toList() : null;
