import 'package:equatable/equatable.dart';

/// One renderer-to-agent message (`renderer_to_agent.json`).
///
/// Each subclass serialises itself; [toJson] is the whole wire object,
/// `version` included, so a message built here and the canonical example in
/// `docs/a2ui/v1.0/examples/` compare JSON-equal (spec `frontend_v1/0001`
/// AC-1).
sealed class RendererMessage extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const RendererMessage();

  /// The message as it goes on the wire.
  Map<String, Object?> toJson();
}

/// `action` — a user-initiated event on a surface (ADR-M D-7).
final class ActionMessage extends RendererMessage {
  /// Creates the action.
  const ActionMessage({
    required this.name,
    required this.surfaceId,
    required this.sourceComponentId,
    required this.timestamp,
    this.context = const <String, Object?>{},
  });

  /// The catalog's action name, e.g. `drill_attribution`.
  final String name;

  /// Where the event happened.
  final String surfaceId;

  /// The component that raised it.
  final String sourceComponentId;

  /// ISO 8601, UTC — supplied by the caller, never read here.
  final String timestamp;

  /// The resolved context, e.g. `{driver: LINK}`.
  final Map<String, Object?> context;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': 'v1.0',
    'action': <String, Object?>{
      'name': name,
      'surfaceId': surfaceId,
      'sourceComponentId': sourceComponentId,
      'timestamp': timestamp,
      'context': context,
    },
  };

  @override
  List<Object?> get props => <Object?>[
    name,
    surfaceId,
    sourceComponentId,
    timestamp,
    context,
  ];
}

/// `callAgentFunction` — the renderer asks the agent to run [call].
final class CallAgentFunction extends RendererMessage {
  /// Creates the call.
  const CallAgentFunction({
    required this.surfaceId,
    required this.functionCallId,
    required this.call,
    this.catalogId,
    this.args = const <String, Object?>{},
  });

  /// The surface the call originated from.
  final String surfaceId;

  /// The renderer's id for this call; the response echoes it.
  final String functionCallId;

  /// The catalog function, e.g. `renderView`.
  final String call;

  /// The catalog that declares [call], when not the surface's default.
  final String? catalogId;

  /// The arguments, validated by the agent against the function's schema.
  final Map<String, Object?> args;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': 'v1.0',
    'callAgentFunction': <String, Object?>{
      'surfaceId': surfaceId,
      'functionCallId': functionCallId,
      'callFunction': <String, Object?>{
        'call': call,
        'catalogId': ?catalogId,
        'args': args,
      },
    },
  };

  @override
  List<Object?> get props => <Object?>[
    surfaceId,
    functionCallId,
    call,
    catalogId,
    args,
  ];
}

/// The validation codes the schema reserves; every other code is generic.
const Set<String> validationCodes = <String>{
  'VALIDATION_FAILED',
  'UNALLOWED_PARENT',
  'UNALLOWED_CHILD',
};

/// `error` — something the renderer could not apply.
///
/// A validation error ([validationCodes]) carries [surfaceId] and [path]; a
/// generic one carries [surfaceId] **or** [functionCallId], never both — the
/// two `oneOf` branches of the schema.
final class RendererError extends RendererMessage {
  /// Creates the error.
  const RendererError({
    required this.code,
    required this.message,
    this.surfaceId,
    this.path,
    this.functionCallId,
  });

  /// `UNALLOWED_PARENT`, `VALIDATION_FAILED`, `UNKNOWN_FUNCTION`, …
  final String code;

  /// One or two sentences.
  final String message;

  /// The surface it happened on.
  final String? surfaceId;

  /// A JSON Pointer to the field at fault (validation errors).
  final String? path;

  /// The function call it answers (generic errors).
  final String? functionCallId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': 'v1.0',
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'surfaceId': ?surfaceId,
      'path': ?path,
      'functionCallId': ?functionCallId,
    },
  };

  @override
  List<Object?> get props => <Object?>[
    code,
    message,
    surfaceId,
    path,
    functionCallId,
  ];
}
