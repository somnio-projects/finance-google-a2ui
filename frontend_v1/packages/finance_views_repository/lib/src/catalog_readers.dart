/// The narrow readers every catalog model decodes through.
///
/// One place that turns a served JSON cell into a typed field and raises a
/// `PayloadContractException` naming the path when it cannot (N-3), so the
/// three model files hold shape and nothing else.
library;

import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';

/// Reads the string at [key] of [json], naming `[path].[key]` when it is not
/// one — the same loud failure `ViewPayload.text` gives (N-3).
String catalogString(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String) {
    throw PayloadContractException(ContractFailure('$path.$key', 'a string'));
  }
  return value;
}

/// Reads the optional string at [key]: absent or `null` is an answer.
String? catalogOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

/// Reads the array of strings at [key], in the order the backend wrote them.
List<String> catalogStrings(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! List) {
    throw PayloadContractException(ContractFailure('$path.$key', 'an array'));
  }
  return <String>[
    for (final item in value)
      if (item is String)
        item
      else
        throw PayloadContractException(
          ContractFailure('$path.$key', 'an array of strings'),
        ),
  ];
}

/// Reads the array of objects at [key] into [decode], in arrival order.
List<T> catalogRows<T>(
  Map<String, dynamic> json,
  String key,
  String path,
  T Function(Map<String, dynamic> row, String rowPath) decode,
) {
  final value = json[key];
  if (value is! List) {
    throw PayloadContractException(ContractFailure('$path.$key', 'an array'));
  }
  return <T>[
    for (final (index, row) in value.indexed)
      if (row is Map<String, dynamic>)
        decode(row, '$path.$key[$index]')
      else
        throw PayloadContractException(
          ContractFailure('$path.$key', 'an array of objects'),
        ),
  ];
}
