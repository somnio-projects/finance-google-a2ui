import 'package:a2ui_v1/src/agent_message.dart';
import 'package:a2ui_v1/src/component_node.dart';
import 'package:a2ui_v1/src/protocol.dart';
import 'package:a2ui_v1/src/renderer_message.dart';
import 'package:a2ui_v1/src/wire_reader.dart';
import 'package:equatable/equatable.dart';

/// One message of a `DataPart`, read — or the reason it could not be.
///
/// A value rather than an exception because the list is **not
/// transactional**: the extension spec requires the receiver to report the
/// bad message and carry on with the rest.
sealed class Decoded extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const Decoded();
}

/// A message that was read.
final class DecodedMessage extends Decoded {
  /// Wraps [message].
  const DecodedMessage(this.message);

  /// The message.
  final AgentMessage message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// A message that was not, with the error to report for it.
final class DecodeFailure extends Decoded {
  /// Wraps [error].
  const DecodeFailure(this.error);

  /// A `VALIDATION_FAILED` error naming the field at fault.
  final RendererError error;

  @override
  List<Object?> get props => <Object?>[error];
}

/// Reads one agent-to-renderer message.
Decoded decodeAgentMessage(Object? json) {
  try {
    return DecodedMessage(_read(readObject(json, '')));
  } on A2uiFormatException catch (failure) {
    return DecodeFailure(
      RendererError(
        code: 'VALIDATION_FAILED',
        message: failure.message,
        path: failure.path,
        surfaceId: _surfaceIdOf(json),
      ),
    );
  }
}

AgentMessage _read(Map<String, Object?> envelope) {
  if (envelope['version'] != A2uiProtocol.version) {
    throw const A2uiFormatException('/version', 'expected "v1.0"');
  }
  final keys = envelope.keys.where((key) => key != 'version').toList();
  if (keys.length != 1) {
    throw const A2uiFormatException('', 'expected exactly one message key');
  }
  final kind = keys.single;
  final body = readObject(envelope[kind], '/$kind');
  final path = '/$kind';
  return switch (kind) {
    'createSurface' => CreateSurface(
      surfaceId: readString(body, 'surfaceId', path),
      catalogId: readOptionalString(body, 'catalogId', path),
      components: body.containsKey('components')
          ? _components(body, path)
          : const <ComponentNode>[],
      dataModel: body.containsKey('dataModel')
          ? readObject(body['dataModel'], '$path/dataModel')
          : const <String, Object?>{},
      sendDataModel: body['sendDataModel'] == true,
    ),
    'updateComponents' => UpdateComponents(
      surfaceId: readString(body, 'surfaceId', path),
      components: _components(body, path),
    ),
    'updateDataModel' => _updateDataModel(body, path),
    'deleteSurface' => DeleteSurface(readString(body, 'surfaceId', path)),
    'agentFunctionResponse' => _functionResponse(body, path),
    'callRendererFunction' => CallRendererFunction(
      functionCallId: readString(body, 'functionCallId', path),
      call: readString(
        readObject(body['callFunction'], '$path/callFunction'),
        'call',
        '$path/callFunction',
      ),
    ),
    _ => throw A2uiFormatException(path, 'unknown message "$kind"'),
  };
}

List<ComponentNode> _components(Map<String, Object?> body, String path) {
  final list = readList(body, 'components', path);
  return <ComponentNode>[
    for (var index = 0; index < list.length; index++)
      ComponentNode.fromJson(list[index], '$path/components/$index'),
  ];
}

UpdateDataModel _updateDataModel(Map<String, Object?> body, String path) {
  if (!body.containsKey('value')) {
    throw A2uiFormatException('$path/value', 'value is required');
  }
  return UpdateDataModel(
    surfaceId: readString(body, 'surfaceId', path),
    path: readOptionalString(body, 'path', path) ?? '/',
    value: body['value'],
  );
}

AgentFunctionResponse _functionResponse(
  Map<String, Object?> body,
  String path,
) {
  final id = readString(body, 'functionCallId', path);
  if (body.containsKey('error')) {
    final error = readObject(body['error'], '$path/error');
    return AgentFunctionResponse(
      functionCallId: id,
      error: FunctionError(
        code: readString(error, 'code', '$path/error'),
        message: readString(error, 'message', '$path/error'),
      ),
    );
  }
  if (!body.containsKey('value')) {
    throw A2uiFormatException(path, 'expected a value or an error');
  }
  return AgentFunctionResponse(functionCallId: id, value: body['value']);
}

/// The surface a malformed message was about, when it can still be read —
/// so the error names it, as the schema's validation branch requires.
String? _surfaceIdOf(Object? json) {
  if (json is! Map<String, Object?>) return null;
  for (final body in json.values) {
    if (body is Map<String, Object?> && body['surfaceId'] is String) {
      return body['surfaceId'] as String?;
    }
  }
  return null;
}
