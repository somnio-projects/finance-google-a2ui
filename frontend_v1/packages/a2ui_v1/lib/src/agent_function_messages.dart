part of 'agent_message.dart';

/// The `error` of a function response: a code and a safe sentence.
final class FunctionError extends Equatable {
  /// Creates the error.
  const FunctionError({required this.code, required this.message});

  /// `INVALID_FUNCTION_CALL`, `UNKNOWN_FUNCTION`, … (ADR-M D-6).
  final String code;

  /// The agent's sentence, shown verbatim.
  final String message;

  @override
  List<Object?> get props => <Object?>[code, message];
}

/// `agentFunctionResponse` — the answer to a `callAgentFunction`.
///
/// Exactly one of [value] and [error] is meaningful; [error] is the branch a
/// renderer tests, because a function may legitimately return `null`.
final class AgentFunctionResponse extends AgentMessage {
  /// Creates the message.
  const AgentFunctionResponse({
    required this.functionCallId,
    this.value,
    this.error,
  });

  /// The id the renderer chose for the call it answers.
  final String functionCallId;

  /// The return value.
  final Object? value;

  /// Why the call failed, when it did.
  final FunctionError? error;

  @override
  List<Object?> get props => <Object?>[functionCallId, value, error];
}

/// `callRendererFunction` — the agent asks the renderer to run a function.
///
/// This catalog declares none (spec `backend/0053` §2, *Out*), so the
/// processor answers every one with `UNKNOWN_FUNCTION`, as the protocol
/// requires a renderer to answer each call.
final class CallRendererFunction extends AgentMessage {
  /// Creates the message.
  const CallRendererFunction({
    required this.functionCallId,
    required this.call,
  });

  /// The id the renderer must echo.
  final String functionCallId;

  /// The function's name.
  final String call;

  @override
  List<Object?> get props => <Object?>[functionCallId, call];
}
