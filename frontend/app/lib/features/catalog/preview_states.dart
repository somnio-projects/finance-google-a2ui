import 'package:equatable/equatable.dart';

/// How a Zone 1 state card is produced.
enum PreviewKind {
  /// The catalog's own example payload, as the index thumbnail draws it.
  example,

  /// The same view re-rendered by the backend with declared options.
  options,

  /// The example with its first bucket selected — the card's own state.
  selected,

  /// The example re-rendered with a changed option, changed figures marked.
  recomputed,

  /// The skeleton the Assistant draws while a surface is composed.
  loading,

  /// A state the design draws that no payload can produce; the card says so.
  absent,
}

/// One Zone 1 state of a detail page (spec frontend/0016 §3).
class PreviewState extends Equatable {
  /// Creates a state.
  const PreviewState({
    required this.label,
    required this.kind,
    this.options = const <String, String>{},
    this.note,
  });

  /// The first card of every page: the backend's example, verbatim.
  static const PreviewState example = PreviewState(
    label: 'Default · example payload',
    kind: PreviewKind.example,
  );

  /// What every loading card says under its skeleton.
  static const String loadingNote =
      'The surface the Assistant draws while this view is composed.';

  /// The design's `Loading · skeleton` state.
  static const PreviewState loading = PreviewState(
    label: 'Loading · skeleton',
    kind: PreviewKind.loading,
    note: loadingNote,
  );

  /// The caption above the card. Names the option it sends where it does.
  final String label;

  /// How the card is produced.
  final PreviewKind kind;

  /// The declared options the backend re-renders the view with (N-7).
  final Map<String, String> options;

  /// For [PreviewKind.absent] and [PreviewKind.loading]: why, in one line.
  final String? note;

  @override
  List<Object?> get props => <Object?>[label, kind, options, note];
}
