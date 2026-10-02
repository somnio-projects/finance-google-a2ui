import 'package:equatable/equatable.dart';
import 'package:finance_views_repository/src/catalog_readers.dart';

/// One row of a view's field inventory, as `GET /v1/views` serves it.
///
/// Every cell is a string the backend wrote — `type` already carries its bound
/// (`string ≤32 chars`) — and the two optional cells are `null` where the
/// Markdown contract prints a dash (spec backend/0021 AC-5). The gallery's
/// Zone 2 binds these rows verbatim and derives nothing from them.
class CatalogField extends Equatable {
  /// Creates a row.
  const CatalogField({
    required this.path,
    required this.type,
    required this.presence,
    required this.binding,
    this.state,
    this.input,
  });

  /// Decodes one served row; [path] names it in a contract violation.
  factory CatalogField.fromJson(Map<String, dynamic> json, String path) =>
      CatalogField(
        path: catalogString(json, 'path', path),
        type: catalogString(json, 'type', path),
        presence: catalogString(json, 'presence', path),
        binding: catalogString(json, 'binding', path),
        state: catalogOptionalString(json, 'state'),
        input: catalogOptionalString(json, 'input'),
      );

  /// Dotted path inside the payload; `[]` marks a list.
  final String path;

  /// The declared type with its bound.
  final String type;

  /// `required`, or the default the backend fills in.
  final String presence;

  /// How a client binds it: `display`, `raw`, `text`, `enum`, …
  final String binding;

  /// The component state it drives, or null.
  final String? state;

  /// The option that sets it and its bound, or null when read-only.
  final String? input;

  @override
  List<Object?> get props => <Object?>[
    path,
    type,
    presence,
    binding,
    state,
    input,
  ];
}

/// The do/don't pair the catalog publishes for a designed view.
class CatalogGuidance extends Equatable {
  /// Creates the pair.
  const CatalogGuidance({required this.useWhen, required this.avoidWhen});

  /// Decodes the pair; [path] names it in a contract violation.
  factory CatalogGuidance.fromJson(Map<String, dynamic> json, String path) =>
      CatalogGuidance(
        useWhen: catalogString(json, 'use_when', path),
        avoidWhen: catalogString(json, 'avoid_when', path),
      );

  /// The question this view answers, in the model's words.
  final String useWhen;

  /// The question it does not answer, naming the view that does.
  final String avoidWhen;

  @override
  List<Object?> get props => <Object?>[useWhen, avoidWhen];
}

/// One action a surface rendered from a view may send back.
class CatalogAction extends Equatable {
  /// Creates the declaration.
  const CatalogAction({
    required this.action,
    required this.label,
    required this.arg,
    required this.control,
  });

  /// Decodes one served declaration; [path] names it in a violation.
  factory CatalogAction.fromJson(Map<String, dynamic> json, String path) =>
      CatalogAction(
        action: catalogString(json, 'action', path),
        label: catalogString(json, 'label', path),
        arg: catalogString(json, 'arg', path),
        control: catalogString(json, 'control', path),
      );

  /// The registered action id, e.g. `drill.attribution.v1`.
  final String action;

  /// The words the backend wrote for it.
  final String label;

  /// The single argument it takes.
  final String arg;

  /// How that argument is bounded: `choice` or `text`.
  final String control;

  @override
  List<Object?> get props => <Object?>[action, label, arg, control];
}
