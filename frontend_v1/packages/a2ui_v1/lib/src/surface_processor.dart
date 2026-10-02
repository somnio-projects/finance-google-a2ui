import 'package:a2ui_v1/src/agent_message.dart';
import 'package:a2ui_v1/src/agent_message_codec.dart';
import 'package:a2ui_v1/src/renderer_message.dart';
import 'package:a2ui_v1/src/surface.dart';
import 'package:equatable/equatable.dart';

/// What applying a batch of messages produced.
final class ProcessOutcome extends Equatable {
  /// Creates the outcome.
  const ProcessOutcome({
    required this.surfaces,
    this.errors = const <RendererError>[],
    this.responses = const <AgentFunctionResponse>[],
  });

  /// The surfaces after every message that could be applied.
  final SurfaceSet surfaces;

  /// One error per message that could not, in order — what the renderer
  /// reports instead of stopping.
  final List<RendererError> errors;

  /// The function responses the batch carried, for whoever made the calls.
  final List<AgentFunctionResponse> responses;

  @override
  List<Object?> get props => <Object?>[surfaces, errors, responses];
}

/// Applies agent-to-renderer messages to a [SurfaceSet].
///
/// Pure: the set goes in, a new set comes out. The extension spec's
/// processing rules are the contract — messages are applied **in order**, a
/// message that fails is reported and **the rest still apply**, and nothing
/// is atomic beyond one message. A caller repaints once per batch, which is
/// the spec's "SHOULD NOT repaint until all messages have been processed".
final class SurfaceProcessor {
  /// Creates the processor.
  const SurfaceProcessor();

  /// Applies [batch] to [surfaces].
  ProcessOutcome process(SurfaceSet surfaces, Iterable<Decoded> batch) {
    var current = surfaces;
    final errors = <RendererError>[];
    final responses = <AgentFunctionResponse>[];
    for (final decoded in batch) {
      switch (decoded) {
        case DecodeFailure(:final error):
          errors.add(error);
        case DecodedMessage(:final message):
          if (message is AgentFunctionResponse) responses.add(message);
          final step = _apply(current, message);
          current = step.surfaces;
          if (step.error != null) errors.add(step.error!);
      }
    }
    return ProcessOutcome(
      surfaces: current,
      errors: errors,
      responses: responses,
    );
  }

  ({SurfaceSet surfaces, RendererError? error}) _apply(
    SurfaceSet set,
    AgentMessage message,
  ) {
    switch (message) {
      case CreateSurface(:final surfaceId):
        if (set[surfaceId] != null) {
          return _fail(set, surfaceId, 'SURFACE_EXISTS', 'already exists');
        }
        final surface = Surface(
          id: surfaceId,
          catalogId: message.catalogId,
          dataModel: message.dataModel,
        ).withComponents(message.components);
        return (surfaces: set.put(surface), error: null);
      case UpdateComponents(:final surfaceId, :final components):
        final surface = set[surfaceId];
        if (surface == null) return _unknown(set, surfaceId);
        return (
          surfaces: set.put(surface.withComponents(components)),
          error: null,
        );
      case UpdateDataModel(:final surfaceId, :final path, :final value):
        final surface = set[surfaceId];
        if (surface == null) return _unknown(set, surfaceId);
        try {
          return (
            surfaces: set.put(surface.withData(path, value)),
            error: null,
          );
        } on FormatException catch (failure) {
          return (
            surfaces: set,
            error: RendererError(
              code: 'VALIDATION_FAILED',
              message: failure.message,
              surfaceId: surfaceId,
              path: '/updateDataModel/path',
            ),
          );
        }
      case DeleteSurface(:final surfaceId):
        if (set[surfaceId] == null) return _unknown(set, surfaceId);
        return (surfaces: set.remove(surfaceId), error: null);
      case AgentFunctionResponse():
        return (surfaces: set, error: null);
      case CallRendererFunction(:final functionCallId, :final call):
        return (
          surfaces: set,
          error: RendererError(
            code: 'UNKNOWN_FUNCTION',
            message: 'this renderer registers no function "$call"',
            functionCallId: functionCallId,
          ),
        );
    }
  }

  ({SurfaceSet surfaces, RendererError? error}) _unknown(
    SurfaceSet set,
    String surfaceId,
  ) => _fail(set, surfaceId, 'SURFACE_NOT_FOUND', 'was never created');

  ({SurfaceSet surfaces, RendererError? error}) _fail(
    SurfaceSet set,
    String surfaceId,
    String code,
    String reason,
  ) => (
    surfaces: set,
    error: RendererError(
      code: code,
      message: 'surface "$surfaceId" $reason',
      surfaceId: surfaceId,
    ),
  );
}
