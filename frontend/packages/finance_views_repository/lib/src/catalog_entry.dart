import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/catalog_facts.dart';
import 'package:finance_views_repository/src/catalog_readers.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';
import 'package:finance_views_repository/src/view_payload.dart';

/// One entry of `GET /v1/views` — what the backend can render and how.
///
/// The developer catalog (spec frontend/0016) binds these fields and nothing
/// else: the words, the inventory, the prompt fragment and the example are
/// all the backend's, verbatim. [optionNames] is read so a caller can keep
/// N-7 — send only an option the view declares — without interpreting the
/// schema itself; the bounds inside it stay the backend's to enforce (N-8).
class CatalogEntry extends Equatable {
  /// Creates an entry.
  const CatalogEntry({
    required this.id,
    required this.summary,
    required this.component,
    required this.endpoints,
    required this.optionNames,
    required this.fields,
    required this.actions,
    required this.prompt,
    required this.example,
    this.guidance,
  });

  /// Decodes one served entry, throwing [PayloadContractException] when the
  /// shape is not the one the contract declares (N-3).
  factory CatalogEntry.fromJson(Object? json, {String path = 'views[]'}) {
    if (json is! Map<String, dynamic>) {
      throw PayloadContractException(ContractFailure(path, 'a JSON object'));
    }
    final guidance = json['guidance'];
    final schema = json['options_schema'];
    if (schema is! Map<String, dynamic>) {
      throw PayloadContractException(
        ContractFailure('$path.options_schema', 'a JSON schema object'),
      );
    }
    final properties = schema['properties'];
    return CatalogEntry(
      id: catalogString(json, 'id', path),
      summary: catalogString(json, 'summary', path),
      component: catalogString(json, 'component', path),
      endpoints: catalogStrings(json, 'endpoints', path),
      // The property names, in the order the schema lists them. Their
      // bounds are not read: a declared bound is data to offer, never a
      // rule to compile here (N-5, N-8).
      optionNames: properties is Map<String, dynamic>
          ? properties.keys.toList()
          : const <String>[],
      fields: catalogRows(json, 'fields', path, CatalogField.fromJson),
      actions: catalogRows(json, 'actions', path, CatalogAction.fromJson),
      guidance: guidance is Map<String, dynamic>
          ? CatalogGuidance.fromJson(guidance, '$path.guidance')
          : null,
      prompt: catalogString(json, 'prompt', path),
      example: ViewPayload.fromJson(json['example']),
    );
  }

  /// The frozen view id, e.g. `holdings.allocation.v1`.
  final String id;

  /// What the projection shows, in the backend's one line.
  final String summary;

  /// The A2UI component the client registers against.
  final String component;

  /// The endpoints that serve it, as the backend spells them.
  final List<String> endpoints;

  /// The names of the options the view declares, in schema order.
  final List<String> optionNames;

  /// The field inventory of the rendered payload.
  final List<CatalogField> fields;

  /// The actions a rendered surface may send back; empty for most views.
  final List<CatalogAction> actions;

  /// The do/don't pair, or null where design has not written a page.
  final CatalogGuidance? guidance;

  /// The lines the system prompt carries for this view, verbatim.
  final String prompt;

  /// A payload the projection really renders.
  final ViewPayload example;

  /// Whether the view declares [option], so a caller may send it (N-7).
  bool declares(String option) => optionNames.contains(option);

  @override
  List<Object?> get props => <Object?>[
    id,
    summary,
    component,
    endpoints,
    optionNames,
    fields,
    actions,
    guidance,
    prompt,
    example,
  ];
}
