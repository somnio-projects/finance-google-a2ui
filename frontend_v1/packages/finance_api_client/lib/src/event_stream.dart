/// Decoding `text/event-stream` bytes into one JSON object per event.
///
/// This is the **only** file in the agent path allowed to call `jsonDecode`,
/// alongside `finance_api_client.dart`: N-5 bans interpreting a
/// server-supplied string anywhere else, and the transport is precisely where
/// a response stops being text and becomes data
/// (`binding_rules_test.dart::nothing interprets a server-supplied string`
/// carries both allowances).
library;

import 'dart:convert';

/// Decodes [body] into one decoded object per server-sent event.
///
/// Narrow by design: this backend emits only `data:` lines terminated by a
/// blank line (`a2a_events.py::sse`). Every other SSE field — `event:`, `id:`,
/// `retry:` and comment lines — is ignored rather than modelled, because the
/// surface uses none of them and inventing support for one would be claiming a
/// capability the server does not have.
///
/// **Reads to the end of the stream.** A turn reports failure *after* its
/// terminal `final: true` status (spec `client/0003` §8.5), so a consumer that
/// stopped at the terminal event would show "failed" with no reason. The
/// trailing flush below is what makes the last event survive a body that ends
/// without its blank line.
///
/// An event whose payload is not a JSON object is dropped rather than raised:
/// a stream is consumed one event at a time and there is no caller left to
/// return a `Result` to. The turn then ends without its terminal event, which
/// the repository above reports as an incomplete turn.
Stream<Map<String, dynamic>> decodeEventStream(Stream<List<int>> body) async* {
  final data = StringBuffer();
  final lines = body.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      final event = decodeJsonObject(data.toString());
      data.clear();
      if (event != null) yield event;
      continue;
    }
    if (!line.startsWith('data:')) continue;
    final chunk = line.substring(5);
    // SSE strips exactly one optional space after the colon — not every
    // leading space, which would corrupt a payload that begins with one.
    data.write(chunk.startsWith(' ') ? chunk.substring(1) : chunk);
  }
  final trailing = decodeJsonObject(data.toString());
  if (trailing != null) yield trailing;
}

/// Decodes [source] to a JSON object, or `null` when it is not one.
///
/// Returns `null` rather than throwing so a malformed frame cannot take the
/// whole turn down, and so no decoder exception crosses a layer boundary.
Map<String, dynamic>? decodeJsonObject(String source) {
  if (source.isEmpty) return null;
  try {
    final decoded = jsonDecode(source);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
