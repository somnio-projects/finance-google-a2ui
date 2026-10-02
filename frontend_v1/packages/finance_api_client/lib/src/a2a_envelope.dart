/// The JSON-RPC envelope of one `message/stream` call (ADR-J D-2).
///
/// [part] is the message's single part — a `text` part or a surface action's
/// `data` part — so the wire shape lives in one place and the client above
/// decides only which of the two it is sending.
Map<String, dynamic> a2aEnvelope(
  Map<String, dynamic> part,
  String messageId,
  String? contextId,
  String requestId,
) => <String, dynamic>{
  'jsonrpc': '2.0',
  'id': requestId,
  'method': 'message/stream',
  'params': <String, dynamic>{
    'message': <String, dynamic>{
      'role': 'user',
      'messageId': messageId,
      'contextId': ?contextId,
      'parts': <Map<String, dynamic>>[part],
    },
  },
};
