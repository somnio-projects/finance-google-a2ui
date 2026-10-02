import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/agent_event.dart';
import 'package:finance_views_repository/src/agent_event_parser.dart';
import 'package:finance_views_repository/src/surface_action_request.dart';

/// Runs agent turns and reports them as a stream of [AgentEvent].
///
/// The repository layer's half of the A2UI path: it owns the protocol's
/// shape, so the bloc above it never sees a JSON map, a status code or an SSE
/// frame — the same boundary `ViewsRepository` keeps for reads.
///
/// **Every failure is an event, not a thrown exception**, because a turn can
/// fail after it has already produced surfaces and a partly-consumed stream
/// has no caller left to return a `Result` to. Nothing throws across this
/// boundary (ADR-L D-8) — including an error raised **on** the stream rather
/// than carried in it, which is the case this sentence described and did not
/// cover until spec `frontend/0018`.
class AgentRepository {
  /// Creates a repository over [a2aClient].
  AgentRepository({required A2aClient a2aClient}) : _a2aClient = a2aClient;

  final A2aClient _a2aClient;

  /// Runs one turn for [text] and yields its events as they arrive.
  ///
  /// The stream is read **to its end**, not to the terminal status: a failed
  /// turn reports its reason in an `error` event that arrives *after*
  /// `final: true` (spec `client/0003` §8.5), so stopping early would show a
  /// failure with no explanation.
  ///
  /// [contextId] is echoed by the server for correlation only and is never
  /// trusted as an identity (ADR-J D-4); omitting it is not an error.
  Stream<AgentEvent> startTurn({
    required String messageId,
    String? text,
    SurfaceActionRequest? action,
    String? contextId,
  }) async* {
    final opened = await _a2aClient.startTurn(
      text: text,
      action: action?.action,
      actionArgs: action?.args ?? const <String, String>{},
      messageId: messageId,
      contextId: contextId,
    );
    switch (opened) {
      case Err<Stream<Map<String, dynamic>>>(:final failure):
        // A refusal before the stream existed — a 401 problem document, a
        // JSON-RPC error at HTTP 200, or an unreachable service. It is
        // reported in the same shape as an in-stream failure so the bloc has
        // exactly one failure path to handle.
        yield AgentFailed(code: failure.code, message: failure.message);
      case Ok<Stream<Map<String, dynamic>>>(:final value):
        yield* _events(value);
    }
  }

  /// The message shown when the turn's stream dies under us.
  ///
  /// Ours, not the backend's, because at this point the backend has said
  /// nothing — that is the failure. It is a fixed, safe sentence for the same
  /// reason `A2aClient` never passes `http.ClientException.message` through:
  /// on `BrowserClient` that text carries the target URL (N-14).
  static const String _streamFailed = 'the agent stopped answering';

  Stream<AgentEvent> _events(Stream<Map<String, dynamic>> raw) async* {
    // A failure ON the stream, as opposed to one reported IN it.
    //
    // This class's contract is that every failure is an event and nothing
    // throws across the boundary (ADR-L D-8), and until 2026-09-22 that was
    // false for exactly the case the contract names: a turn that fails
    // **after** it has produced surfaces. `A2aClient` guards `send()` and the
    // response's interpretation, but once it hands back `Ok(stream)`, a
    // connection reset, an SSE the edge closed, or a read timeout surfaces as
    // an error on THIS stream — which `await for` rethrows, straight out of
    // `ConversationBloc._run`'s own `await for` and out of its event handler.
    // Bloc reports that to `onError` and leaves the state untouched, so the
    // status stays `running`: the typing indicator never stops and the
    // composer never re-enables. The turn is over and the app cannot know.
    //
    // `on Object` rather than a narrower clause on purpose: what arrives here
    // is whatever the transport chose to raise, across web and VM, and a
    // clause narrow enough to miss one of them would restore the hang for
    // that one. There is no failure on this stream that should reach the UI
    // as an exception.
    try {
      await for (final frame in raw) {
        final event = parseAgentEvent(frame);
        if (event != null) yield event;
      }
    } on Object {
      yield const AgentFailed(
        code: 'transport-unavailable',
        message: _streamFailed,
      );
    }
  }
}
