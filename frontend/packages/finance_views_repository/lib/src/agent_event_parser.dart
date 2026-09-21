import 'package:finance_views_repository/src/agent_event.dart';

/// Turns one decoded A2A event into an [AgentEvent].
///
/// Returns `null` for anything this client does not model — an unknown
/// `kind`, or a known kind whose required fields are missing. **Ignoring is
/// the right answer, not raising**: the surface adds event kinds additively
/// (`a2a_events.py` says so of `render-intent` itself), so a client that
/// failed on an unrecognised event would break every time the server grew
/// one. A malformed *known* event is dropped for the same reason a malformed
/// frame is: there is no caller left to hand a `Result` to mid-stream, and the
/// turn then ends without its terminal event, which the bloc reports.
AgentEvent? parseAgentEvent(Map<String, dynamic> event) {
  return switch (event['kind']) {
    'status-update' => _status(event),
    'render-intent' => _surface(event),
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

AgentEvent? _surface(Map<String, dynamic> event) {
  final intent = event['renderIntent'];
  final index = event['index'];
  if (intent is! Map<String, dynamic> || index is! int) return null;
  final view = intent['view'];
  if (view is! String) return null;
  return AgentSurfaceReady(
    index: index,
    view: view,
    options: readOptions(intent['options']),
  );
}

AgentEvent? _answer(Map<String, dynamic> event) {
  final parts = event['parts'];
  final intents = event['renderIntents'];
  if (parts is! List) return null;
  return AgentAnswered(
    text: _text(parts),
    views: <String>[
      if (intents is List)
        for (final intent in intents)
          if (intent is Map<String, dynamic> && intent['view'] is String)
            intent['view'] as String,
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

/// Reads a render intent's `options` as query values.
///
/// Only scalars survive: the read endpoint takes flat query parameters, so a
/// nested object or list has no query encoding this client is allowed to
/// invent (N-7 — options are the server's schema, not ours to extend). A
/// dropped option is safer than a guessed one, which would be a 422 for the
/// whole request.
Map<String, String> readOptions(Object? options) {
  if (options is! Map<String, dynamic>) return const <String, String>{};
  return <String, String>{
    for (final entry in options.entries)
      if (entry.value is String || entry.value is num || entry.value is bool)
        entry.key: '${entry.value}',
  };
}
