part of 'conversation_bloc.dart';

/// What opened a turn, kept so a failed one can be sent again (GGU-111).
///
/// Exactly what `_run` was given: a sentence **or** A2UI renderer-to-agent
/// messages (a surface's `action`), never both. The retry sends the same
/// thing and echoes nothing — the bubble that asked is already in the
/// transcript. An action is resent with its original `timestamp`: it is the
/// same tap, not a new one.
final class TurnRequest extends Equatable {
  /// Creates the record.
  const TurnRequest({this.text, this.messages = const <RendererMessage>[]});

  /// The typed sentence (or a chip's words), when that is what was sent.
  final String? text;

  /// The A2UI messages, when a surface sent them.
  final List<RendererMessage> messages;

  @override
  List<Object?> get props => <Object?>[text, messages];
}
