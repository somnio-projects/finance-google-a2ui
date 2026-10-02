import 'package:a2ui_v1/src/agent_message_codec.dart';
import 'package:a2ui_v1/src/protocol.dart';
import 'package:a2ui_v1/src/renderer_message.dart';
import 'package:a2ui_v1/src/renderer_message_codec.dart';

/// Whether [part] is an A2A `DataPart` carrying A2UI messages — the
/// `metadata.mimeType` the extension spec defines, and nothing else.
bool isA2uiDataPart(Object? part) {
  if (part is! Map<String, Object?>) return false;
  final metadata = part['metadata'];
  return part['kind'] == 'data' &&
      metadata is Map<String, Object?> &&
      metadata['mimeType'] == A2uiProtocol.mimeType;
}

/// Reads every agent-to-renderer message in [part], one outcome each, in
/// order.
///
/// A part that is not A2UI, or whose `data` is not an array, yields a single
/// [DecodeFailure]: there is no message to isolate the fault to.
List<Decoded> decodeAgentDataPart(Object? part) {
  final data = _data(part);
  if (data == null) {
    return const <Decoded>[
      DecodeFailure(
        RendererError(
          code: 'VALIDATION_FAILED',
          message: 'expected an A2UI DataPart whose data is an array',
          path: '/data',
        ),
      ),
    ];
  }
  return <Decoded>[for (final message in data) decodeAgentMessage(message)];
}

/// Reads every renderer-to-agent message in [part].
///
/// The renderer only ever *writes* these; the reader exists so the suite can
/// prove a built message and the canonical example are the same JSON.
/// Throws [FormatException] on anything else, because its only caller is a
/// test that wants to fail loudly.
List<RendererMessage> decodeRendererDataPart(Object? part) {
  final data = _data(part);
  if (data == null) {
    throw const FormatException('not an A2UI DataPart');
  }
  return <RendererMessage>[
    for (final message in data) decodeRendererMessage(message),
  ];
}

/// Wraps [messages] in the `DataPart` the A2A message carries.
Map<String, Object?> encodeDataPart(List<RendererMessage> messages) =>
    <String, Object?>{
      'kind': 'data',
      'metadata': <String, Object?>{'mimeType': A2uiProtocol.mimeType},
      'data': <Map<String, Object?>>[
        for (final message in messages) message.toJson(),
      ],
    };

List<Object?>? _data(Object? part) {
  if (!isA2uiDataPart(part)) return null;
  final data = (part! as Map<String, Object?>)['data'];
  return data is List<Object?> ? data : null;
}
