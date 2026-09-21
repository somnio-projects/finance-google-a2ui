import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/agent_event.dart';
import 'package:finance_views_repository/src/agent_event_parser.dart';

/// Runs agent turns and reports them as a stream of [AgentEvent].
///
/// The repository layer's half of the A2UI path: it owns the protocol's
/// shape, so the bloc above it never sees a JSON map, a status code or an SSE
/// frame — the same boundary `ViewsRepository` keeps for reads.
///
/// **Every failure is an event, not a thrown exception**, because a turn can
/// fail after it has already produced surfaces and a partly-consumed stream
/// has no caller left to return a `Result` to. Nothing throws across this
/// boundary (ADR-L D-8).
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
    required String text,
    required String messageId,
    String? contextId,
  }) async* {
    final opened = await _a2aClient.startTurn(
      text: text,
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

  Stream<AgentEvent> _events(Stream<Map<String, dynamic>> raw) async* {
    await for (final frame in raw) {
      final event = parseAgentEvent(frame);
      if (event != null) yield event;
    }
  }
}
