import 'package:a2ui_v1/src/component_node.dart';
import 'package:equatable/equatable.dart';

part 'agent_function_messages.dart';

/// One agent-to-renderer message (`agent_to_renderer.json`).
///
/// `sealed`, so the processor's `switch` is exhaustive and a seventh message
/// kind is a compile error in every handler that forgot it.
sealed class AgentMessage extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const AgentMessage();
}

/// `createSurface` — a new surface, optionally with its components and its
/// initial data model inline (ADR-M D-3 sends both).
final class CreateSurface extends AgentMessage {
  /// Creates the message.
  const CreateSurface({
    required this.surfaceId,
    this.catalogId,
    this.components = const <ComponentNode>[],
    this.dataModel = const <String, Object?>{},
    this.sendDataModel = false,
  });

  /// The surface's id, unique for the renderer's lifetime.
  final String surfaceId;

  /// The default catalog of the surface's components and functions.
  final String? catalogId;

  /// The adjacency list, in wire order.
  final List<ComponentNode> components;

  /// The initial root data model.
  final Map<String, Object?> dataModel;

  /// Whether the agent asked for the data model back on every message.
  final bool sendDataModel;

  @override
  List<Object?> get props => <Object?>[
    surfaceId,
    catalogId,
    components,
    dataModel,
    sendDataModel,
  ];
}

/// `updateComponents` — upserts components into an existing surface.
final class UpdateComponents extends AgentMessage {
  /// Creates the message.
  const UpdateComponents({required this.surfaceId, required this.components});

  /// The surface being updated.
  final String surfaceId;

  /// The components to add or replace, by id.
  final List<ComponentNode> components;

  @override
  List<Object?> get props => <Object?>[surfaceId, components];
}

/// `updateDataModel` — replaces the value at [path]; a `null` [value] deletes
/// the key there.
final class UpdateDataModel extends AgentMessage {
  /// Creates the message.
  const UpdateDataModel({
    required this.surfaceId,
    required this.value,
    this.path = '/',
  });

  /// The surface being updated.
  final String surfaceId;

  /// A JSON Pointer; `/` (the default) is the whole data model.
  final String path;

  /// The new value, verbatim, or `null` to delete.
  final Object? value;

  @override
  List<Object?> get props => <Object?>[surfaceId, path, value];
}

/// `deleteSurface` — removes a surface with its components and data.
final class DeleteSurface extends AgentMessage {
  /// Creates the message.
  const DeleteSurface(this.surfaceId);

  /// The surface to remove.
  final String surfaceId;

  @override
  List<Object?> get props => <Object?>[surfaceId];
}
