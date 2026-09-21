import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';
import 'package:finance_views_repository/src/raw_decimal.dart';

/// One rendered projection, read by dotted path.
///
/// This is the whole of the client's "model layer", and the absence of a
/// generated DTO per view is deliberate (ADR-L D-4): the single source of
/// truth for a payload's shape is the backend's own generated catalog, and a
/// hand-or-tool-written Dart mirror of it is a second source that can drift.
/// A reader that fails loudly on a missing path enforces the same contract
/// without duplicating it.
///
/// Every text accessor returns a **string the backend already formatted**.
/// There is deliberately no general-purpose `double` or `num` accessor: one
/// would be the first step of prohibition N-1, and its absence is what makes
/// the rule cheap to keep. [geometry] is the single, named exception, and its
/// doc comment says what it may and may not be used for (ADR-L D-14).
class ViewPayload extends Equatable {
  /// Wraps the decoded JSON object of a single view.
  const ViewPayload(this.view, this._json);

  /// Builds a payload from a decoded JSON value, or throws when it is not an
  /// object carrying the `view` discriminator the contract requires.
  factory ViewPayload.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const PayloadContractException(
        ContractFailure('<root>', 'a JSON object'),
      );
    }
    final view = json['view'];
    if (view is! String) {
      throw const PayloadContractException(
        ContractFailure('view', 'the view discriminator'),
      );
    }
    return ViewPayload(view, json);
  }

  /// The frozen view id this payload was rendered for, e.g.
  /// `holdings.allocation.v1`.
  final String view;

  final Map<String, dynamic> _json;

  /// Reads the string at [path], e.g. `total.amount.display`.
  ///
  /// Throws [PayloadContractException] when the path is absent or is not a
  /// string, because that means the payload broke the contract (N-3).
  String text(String path) {
    final value = _at(path);
    if (value is! String) {
      throw PayloadContractException(ContractFailure(path, 'a string'));
    }
    return value;
  }

  /// Reads the string at [path], or `null` when the contract marks it
  /// optional and the backend omitted it.
  String? optionalText(String path) {
    final value = _at(path);
    return value is String ? value : null;
  }

  /// Reads the raw decimal at [path] as a `double`, **for chart geometry**.
  ///
  /// The contract keeps a raw `amount` beside every `*.display` string so a
  /// chart can be drawn from it, and a responsive chart cannot get its
  /// value-to-pixel mapping from the server, which does not know the width it
  /// will be laid out in. This is that seam and the only one: the result is a
  /// position on a canvas. It never reaches a `Text`, is never re-formatted
  /// and never becomes a figure a human reads — those all arrive already
  /// formatted (N-1, N-2, N-4). See [rawDecimal] and ADR-L D-14.
  ///
  /// Throws [PayloadContractException] when the path is absent or does not
  /// hold a decimal string, for the same reason [text] does (N-3).
  double geometry(String path) {
    final value = _at(path);
    if (value is! String) {
      throw PayloadContractException(ContractFailure(path, 'a decimal string'));
    }
    return rawDecimal(path, value);
  }

  /// Reads the repeated **string** at [path], e.g. `inputs[].choices`.
  ///
  /// The contract publishes a closed list of accepted values as an array of
  /// strings, which [rows] cannot read — it requires objects. This is that
  /// accessor, and it is deliberately narrow: it returns the strings the
  /// backend wrote, in the order it wrote them (N-10), and nothing here
  /// interprets one. A declared bound is data to offer, never a rule to
  /// compile (N-5, N-8).
  ///
  /// Throws [PayloadContractException] when the path is absent or holds
  /// anything but strings, for the same reason [text] does (N-3).
  List<String> strings(String path) {
    final value = _at(path);
    if (value is! List) {
      throw PayloadContractException(ContractFailure(path, 'an array'));
    }
    return <String>[
      for (final item in value)
        if (item is String)
          item
        else
          throw PayloadContractException(
            ContractFailure(path, 'an array of strings'),
          ),
    ];
  }

  /// Reads the repeated object at [path] as a list of nested payloads.
  ///
  /// The rows keep [view] so a nested reader reports the same component in its
  /// contract violations. Rows are returned **in the order the backend sent
  /// them** and are never sorted or filtered here (N-10).
  List<ViewPayload> rows(String path) {
    final value = _at(path);
    if (value is! List) {
      throw PayloadContractException(ContractFailure(path, 'an array'));
    }
    return <ViewPayload>[
      for (final row in value)
        if (row is Map<String, dynamic>)
          ViewPayload(view, row)
        else
          throw PayloadContractException(
            ContractFailure(path, 'an array of objects'),
          ),
    ];
  }

  @override
  List<Object?> get props => <Object?>[view, _json];

  Object? _at(String path) {
    Object? current = _json;
    for (final segment in path.split('.')) {
      if (current is! Map<String, dynamic>) return null;
      current = current[segment];
    }
    return current;
  }
}
