/// The JSON-RPC envelope of one `message/stream` call (ADR-J D-2).
///
/// [part] is the message's single part — a `text` part or an A2UI `DataPart`
/// — so the wire shape lives in one place and the client above decides only
/// which of the two it is sending. [metadata] is `message.metadata`, where a
/// v1.0 renderer advertises `a2uiRendererCapabilities` (ADR-M D-8).
Map<String, dynamic> a2aEnvelope(
  Map<String, dynamic> part,
  String messageId,
  String? contextId,
  String requestId, {
  Map<String, dynamic>? metadata,
}) => <String, dynamic>{
  'jsonrpc': '2.0',
  'id': requestId,
  'method': 'message/stream',
  'params': <String, dynamic>{
    'message': <String, dynamic>{
      'role': 'user',
      'messageId': messageId,
      'contextId': ?contextId,
      'parts': <Map<String, dynamic>>[part],
      'metadata': ?metadata,
    },
  },
};

/// `message.metadata` of a v1.0 renderer: its `a2uiRendererCapabilities`,
/// naming the catalogs it supports (ADR-M D-8; the agent refuses a request
/// whose capabilities lack its catalog).
Map<String, dynamic> rendererMetadata(List<String> catalogIds) =>
    <String, dynamic>{
      'a2uiRendererCapabilities': <String, dynamic>{
        'v1.0': <String, dynamic>{'supportedCatalogIds': catalogIds},
      },
    };
