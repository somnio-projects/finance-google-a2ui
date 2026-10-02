import 'package:a2ui_v1/src/component_node.dart';
import 'package:equatable/equatable.dart';

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

/// The `error` of a function response: a code and a safe sentence.
final class FunctionError extends Equatable {
  /// Creates the error.
  const FunctionError({required this.code, required this.message});

  /// `INVALID_FUNCTION_CALL`, `UNKNOWN_FUNCTION`, … (ADR-M D-6).
  final String code;

  /// The agent's sentence, shown verbatim.
  final String message;

  @override
  List<Object?> get props => <Object?>[code, message];
}

/// `agentFunctionResponse` — the answer to a `callAgentFunction`.
///
/// Exactly one of [value] and [error] is meaningful; [error] is the branch a
/// renderer tests, because a function may legitimately return `null`.
final class AgentFunctionResponse extends AgentMessage {
  /// Creates the message.
  const AgentFunctionResponse({
    required this.functionCallId,
    this.value,
    this.error,
  });

  /// The id the renderer chose for the call it answers.
  final String functionCallId;

  /// The return value.
  final Object? value;

  /// Why the call failed, when it did.
  final FunctionError? error;

  @override
  List<Object?> get props => <Object?>[functionCallId, value, error];
}

/// `callRendererFunction` — the agent asks the renderer to run a function.
///
/// This catalog declares none (spec `backend/0053` §2, *Out*), so the
/// processor answers every one with `UNKNOWN_FUNCTION`, as the protocol
/// requires a renderer to answer each call.
final class CallRendererFunction extends AgentMessage {
  /// Creates the message.
  const CallRendererFunction({
    required this.functionCallId,
    required this.call,
  });

  /// The id the renderer must echo.
  final String functionCallId;

  /// The function's name.
  final String call;

  @override
  List<Object?> get props => <Object?>[functionCallId, call];
}
