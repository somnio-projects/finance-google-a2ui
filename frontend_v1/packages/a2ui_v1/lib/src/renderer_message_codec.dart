import 'package:a2ui_v1/src/protocol.dart';
import 'package:a2ui_v1/src/renderer_message.dart';
import 'package:a2ui_v1/src/wire_reader.dart';

/// Reads one renderer-to-agent message, or throws [FormatException].
///
/// The inverse of [RendererMessage.toJson]. Only the three kinds this
/// renderer sends are modelled; `rendererFunctionResponse` answers a
/// `callRendererFunction`, which this catalog never receives.
RendererMessage decodeRendererMessage(Object? json) {
  try {
    final envelope = readObject(json, '');
    if (envelope['version'] != A2uiProtocol.version) {
      throw const A2uiFormatException('/version', 'expected "v1.0"');
    }
    if (envelope['action'] != null) return _action(envelope['action']);
    if (envelope['callAgentFunction'] != null) {
      return _call(envelope['callAgentFunction']);
    }
    return _error(envelope['error']);
  } on A2uiFormatException catch (failure) {
    throw FormatException('${failure.path}: ${failure.message}');
  }
}

ActionMessage _action(Object? json) {
  const path = '/action';
  final body = readObject(json, path);
  return ActionMessage(
    name: readString(body, 'name', path),
    surfaceId: readString(body, 'surfaceId', path),
    sourceComponentId: readString(body, 'sourceComponentId', path),
    timestamp: readString(body, 'timestamp', path),
    context: readObject(body['context'], '$path/context'),
  );
}

CallAgentFunction _call(Object? json) {
  const path = '/callAgentFunction';
  final body = readObject(json, path);
  final call = readObject(body['callFunction'], '$path/callFunction');
  return CallAgentFunction(
    surfaceId: readString(body, 'surfaceId', path),
    functionCallId: readString(body, 'functionCallId', path),
    call: readString(call, 'call', '$path/callFunction'),
    catalogId: readOptionalString(call, 'catalogId', '$path/callFunction'),
    args: readObject(call['args'], '$path/callFunction/args'),
  );
}

RendererError _error(Object? json) {
  const path = '/error';
  final body = readObject(json, path);
  return RendererError(
    code: readString(body, 'code', path),
    message: readString(body, 'message', path),
    surfaceId: readOptionalString(body, 'surfaceId', path),
    path: readOptionalString(body, 'path', path),
    functionCallId: readOptionalString(body, 'functionCallId', path),
  );
}
