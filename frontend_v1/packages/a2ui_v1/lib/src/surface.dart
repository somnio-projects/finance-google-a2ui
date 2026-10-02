import 'package:a2ui_v1/src/component_node.dart';
import 'package:a2ui_v1/src/json_pointer.dart';
import 'package:a2ui_v1/src/protocol.dart';
import 'package:equatable/equatable.dart';

/// One surface: its catalog, its adjacency list and its data model.
///
/// An immutable value. The processor returns a new one per message, so a
/// Bloc can hold it in state and a widget can compare two of them.
final class Surface extends Equatable {
  /// Creates the surface.
  const Surface({
    required this.id,
    this.catalogId,
    this.components = const <String, ComponentNode>{},
    this.dataModel = const <String, Object?>{},
  });

  /// The id `createSurface` gave it.
  final String id;

  /// The default catalog its components resolve against.
  final String? catalogId;

  /// Every component received so far, by id — in arrival order, which is
  /// what a progressive renderer wants to show first.
  final Map<String, ComponentNode> components;

  /// The surface's data model, the root a JSON Pointer resolves from.
  final Map<String, Object?> dataModel;

  /// Whether `root` has arrived. Until it has, every other component is
  /// buffered and nothing is visible (the adjacency-list model's rule).
  bool get hasRoot => components.containsKey(A2uiProtocol.rootId);

  /// The value at [pointer] in the data model, or `null`.
  Object? read(String pointer) => readPointer(dataModel, pointer);

  /// This surface with [nodes] upserted by id.
  Surface withComponents(Iterable<ComponentNode> nodes) => Surface(
    id: id,
    catalogId: catalogId,
    components: <String, ComponentNode>{
      ...components,
      for (final node in nodes) node.id: node,
    },
    dataModel: dataModel,
  );

  /// This surface with [value] written at [pointer] (`null` deletes).
  ///
  /// Throws [FormatException] for a path the model cannot hold.
  Surface withData(String pointer, Object? value) => Surface(
    id: id,
    catalogId: catalogId,
    components: components,
    dataModel: writePointer(dataModel, pointer, value),
  );

  @override
  List<Object?> get props => <Object?>[id, catalogId, components, dataModel];
}

/// Every live surface, in creation order.
final class SurfaceSet extends Equatable {
  /// Creates the set.
  const SurfaceSet([this.surfaces = const <String, Surface>{}]);

  /// The surfaces by id. Insertion order is creation order.
  final Map<String, Surface> surfaces;

  /// The surface called [id], or `null`.
  Surface? operator [](String id) => surfaces[id];

  /// The set with [surface] added or replaced.
  SurfaceSet put(Surface surface) =>
      SurfaceSet(<String, Surface>{...surfaces, surface.id: surface});

  /// The set without [id].
  SurfaceSet remove(String id) => SurfaceSet(<String, Surface>{
    for (final entry in surfaces.entries)
      if (entry.key != id) entry.key: entry.value,
  });

  @override
  List<Object?> get props => <Object?>[surfaces];
}
