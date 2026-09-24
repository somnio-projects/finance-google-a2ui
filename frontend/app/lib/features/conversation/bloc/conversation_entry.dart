import 'package:equatable/equatable.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

/// One thing the conversation shows, in arrival order.
///
/// `sealed`, so the view's `switch` is exhaustive and a new entry kind is a
/// compile error rather than a blank space on screen.
///
/// Note there is deliberately **no `props` here**. Every subclass overrides
/// it, so a base implementation would be a line no test can reach — the same
/// dead-code coverage gap `.claude/rules/frontend/testing.md` records from the
/// first build of this app. `Equatable` declares it abstract; leaving it that
/// way is what keeps the file at 100 %.
sealed class ConversationEntry extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const ConversationEntry();
}

/// What the user asked.
final class UserSaid extends ConversationEntry {
  /// Records [text], shown back verbatim.
  const UserSaid(this.text);

  /// The message the user typed.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// What the agent answered, in words.
final class AgentSaid extends ConversationEntry {
  /// Records [text], rendered verbatim — the client never rewrites it.
  const AgentSaid(this.text);

  /// The answer the backend wrote.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// A surface the agent asked for, with the payload already fetched.
///
/// It carries the payload and **not** a widget: which component renders it is
/// decided by the one `ComponentRegistry`, at build time, exactly as it is for
/// a surface the user navigated to. There is no second rendering path.
///
/// It also carries the **options it was rendered with**, so an edit of one
/// declared option re-requests the view with the others intact (ADR-K D-11,
/// GGU-113), and the host's answer to the last edit: the option in flight and
/// the backend's sentence when it refused one.
final class AgentSurface extends ConversationEntry {
  /// Records [payload] for the view the agent chose, rendered with [options].
  const AgentSurface(
    this.payload, {
    this.options = const <String, String>{},
    this.pendingOption,
    this.rejection,
  });

  /// The rendered projection, shaped entirely by the backend.
  final ViewPayload payload;

  /// The declared options this payload was rendered with — the agent's
  /// intent, plus every edit since.
  final Map<String, String> options;

  /// The option being re-rendered, or null when none is.
  final String? pendingOption;

  /// The backend's own sentence for the last refused edit, or null.
  final String? rejection;

  /// The same surface while [option] is being re-rendered under [options] —
  /// the merged map, so a second edit made before this one lands merges onto
  /// the newest intent rather than the last rendered one (spec 0026 OD-3).
  AgentSurface editing(String option, Map<String, String> options) =>
      AgentSurface(payload, options: options, pendingOption: option);

  /// The re-rendered surface: a new payload under the [options] that made it.
  AgentSurface rendered(ViewPayload payload, Map<String, String> options) =>
      AgentSurface(payload, options: options);

  /// The edit was refused: the previous payload stays under [options] — the
  /// intent that payload was rendered with, so the refused value is not
  /// re-sent by the next edit — with [message] under it.
  AgentSurface refused(String message, Map<String, String> options) =>
      AgentSurface(payload, options: options, rejection: message);

  @override
  List<Object?> get props => <Object?>[
    payload,
    options,
    pendingOption,
    rejection,
  ];
}

/// A surface the agent asked for that could not be fetched.
///
/// Shown rather than dropped: the turn succeeded and the answer text is still
/// worth reading, so one missing widget degrades that surface alone.
final class SurfaceUnavailable extends ConversationEntry {
  /// Records that [view] could not be shown, because of [message].
  const SurfaceUnavailable({required this.view, required this.message});

  /// The view id the agent chose.
  final String view;

  /// Safe text explaining why — the backend's own, or this app's wording.
  final String message;

  @override
  List<Object?> get props => <Object?>[view, message];
}

/// A surface the agent asked for whose payload has not arrived yet.
///
/// Shown as the design's skeleton (spec frontend/0011 OD-2) and replaced in
/// place by [AgentSurface] or [SurfaceUnavailable], so the transcript keeps
/// the streaming order (N-10).
final class SurfacePending extends ConversationEntry {
  /// Records that [view] is being composed.
  const SurfacePending(this.view);

  /// The view id the agent chose.
  final String view;

  @override
  List<Object?> get props => <Object?>[view];
}
