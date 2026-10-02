part of 'renderer_message.dart';

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
