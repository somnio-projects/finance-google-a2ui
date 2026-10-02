import 'package:a2ui_v1/src/wire_reader.dart';
import 'package:equatable/equatable.dart';

/// The `accessibility` attributes of a component (`common_types.json`).
///
/// Only **literal** strings are read. A `DynamicString` may also be a data
/// binding or a function call; this catalog's agent sends literals, and
/// resolving a binding for a label is not something the renderer is asked to
/// do yet, so a non-literal is ignored rather than guessed at.
final class Accessibility extends Equatable {
  /// Creates the attributes.
  const Accessibility({this.label, this.description});

  /// Reads the attributes from [json], ignoring anything that is not a
  /// literal string.
  factory Accessibility.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const Accessibility();
    final label = json['label'];
    final description = json['description'];
    return Accessibility(
      label: label is String ? label : null,
      description: description is String ? description : null,
    );
  }

  /// The short name assistive technology reads.
  final String? label;

  /// The longer explanation, when the agent sent one.
  final String? description;

  @override
  List<Object?> get props => <Object?>[label, description];
}

/// One entry of a surface's adjacency list.
///
/// It records what the renderer needs to walk the tree — the id, the catalog
/// type, the children it references and the data path it binds — and keeps
/// the full wire object in [properties] for anything a component reads
/// itself.
final class ComponentNode extends Equatable {
  /// Creates the node.
  const ComponentNode({
    required this.id,
    required this.component,
    this.children = const <String>[],
    this.dataPath,
    this.accessibility = const Accessibility(),
    this.properties = const <String, Object?>{},
  });

  /// Reads one component object; [path] locates it for an error.
  factory ComponentNode.fromJson(Object? json, String path) {
    final object = readObject(json, path);
    final data = object['data'];
    return ComponentNode(
      id: readString(object, 'id', path),
      component: readString(object, 'component', path),
      children: _children(object, path),
      dataPath: data is Map<String, Object?> && data['path'] is String
          ? data['path']! as String
          : null,
      accessibility: Accessibility.fromJson(object['accessibility']),
      properties: object,
    );
  }

  /// The component's id, unique within its surface.
  final String id;

  /// The catalog type, e.g. `PortfolioSummary`.
  final String component;

  /// The ids this node references, in order — `children` or a single `child`.
  final List<String> children;

  /// The JSON Pointer of the data model entry this node binds, if any.
  final String? dataPath;

  /// What assistive technology announces for this node.
  final Accessibility accessibility;

  /// The wire object, verbatim.
  final Map<String, Object?> properties;

  @override
  List<Object?> get props => <Object?>[
    id,
    component,
    children,
    dataPath,
    accessibility,
    properties,
  ];
}

/// The static child list. A template `ChildList` (`{componentId, path}`) is
/// a v1.0 feature no component in this catalog uses; it is refused rather
/// than half-supported.
List<String> _children(Map<String, Object?> object, String path) {
  final child = object['child'];
  if (child is String) return <String>[child];
  if (!object.containsKey('children')) return const <String>[];
  final children = object['children'];
  if (children is List<Object?> && children.every((id) => id is String)) {
    return children.cast<String>();
  }
  throw A2uiFormatException(
    '$path/children',
    'expected a static array of component ids',
  );
}
