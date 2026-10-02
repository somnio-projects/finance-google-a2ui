import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_views_repository/src/agent_event.dart';

/// Turns one decoded A2A event of the v1.0 surface into an [AgentEvent].
///
/// Returns `null` for anything this client does not model — an unknown
/// `kind`, or a known kind whose required fields are missing. **Ignoring is
/// the right answer, not raising**: the surface adds event kinds additively,
/// so a client that failed on an unrecognised event would break every time
/// the server grew one. A malformed *known* event is dropped for the same
/// reason a malformed frame is: there is no caller left to hand a `Result` to
/// mid-stream, and the turn then ends without its terminal event, which the
/// bloc reports.
AgentEvent? parseAgentEvent(Map<String, dynamic> event) {
  return switch (event['kind']) {
    'status-update' => _status(event),
    'artifact-update' => _artifact(event),
    'message' => _answer(event),
    'error' => _failure(event),
    _ => null,
  };
}

AgentEvent? _status(Map<String, dynamic> event) {
  final status = event['status'];
  if (status is! Map<String, dynamic>) return null;
  return switch (status['state']) {
    'working' => const AgentTurnStarted(),
    'completed' => const AgentTurnEnded(AgentTurnState.completed),
    // N-11: a normal terminal state, never an error.
    'input_required' => const AgentTurnEnded(AgentTurnState.inputRequired),
    'failed' => const AgentTurnEnded(AgentTurnState.failed),
    _ => null,
  };
}

/// `artifact-update` → the A2UI messages of every A2UI `DataPart` it carries
/// (spec `backend/0053` §3). A part of any other kind is not ours to read.
AgentEvent? _artifact(Map<String, dynamic> event) {
  final artifact = event['artifact'];
  if (artifact is! Map<String, dynamic>) return null;
  final parts = artifact['parts'];
  if (parts is! List) return null;
  final messages = <Decoded>[
    for (final part in parts)
      if (isA2uiDataPart(part)) ...decodeAgentDataPart(part),
  ];
  return messages.isEmpty ? null : AgentSurfaceMessages(messages);
}

AgentEvent? _answer(Map<String, dynamic> event) {
  final parts = event['parts'];
  if (parts is! List) return null;
  final suggestions = event['suggestions'];
  return AgentAnswered(
    text: _text(parts),
    // A chip needs both halves: the key that identifies it and the words to
    // show. One without the other is dropped rather than half-drawn.
    suggestions: <Suggestion>[
      if (suggestions is List)
        for (final chip in suggestions)
          if (chip is Map<String, dynamic> &&
              chip['key'] is String &&
              chip['label'] is String)
            Suggestion(
              key: chip['key'] as String,
              label: chip['label'] as String,
            ),
    ],
  );
}

AgentEvent? _failure(Map<String, dynamic> event) {
  final code = event['code'];
  final message = event['message'];
  if (code is! String || message is! String) return null;
  return AgentFailed(code: code, message: message);
}

/// Joins every text part of a message, in order, verbatim.
String _text(List<dynamic> parts) => <String>[
  for (final part in parts)
    if (part is Map<String, dynamic> &&
        part['kind'] == 'text' &&
        part['text'] is String)
      part['text'] as String,
].join();
