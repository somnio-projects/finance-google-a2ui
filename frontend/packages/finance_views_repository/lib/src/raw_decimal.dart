import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/src/payload_contract_exception.dart';

/// Reads a backend `amount` / `value` decimal string as a `double`, for
/// **chart geometry and nothing else**.
///
/// This is the one file in the workspace allowed to call `double.parse`, and
/// `app/test/architecture/binding_rules_test.dart` names it explicitly — the
/// same shape as `jsonDecode`, which is legitimate only in the transport.
/// Keeping the exemption to a five-line file is the point: the allowance is
/// per file, so anything that grows here inherits it.
///
/// **Why it exists at all.** ADR-K keeps a raw `Decimal` beside every
/// `*Display` string precisely so a chart can be drawn
/// (`.claude/rules/frontend/contract-binding.md`, N-4: "`amount`, `value` and
/// `units` exist for chart geometry"). Until GGU-55 no component drew one, so
/// the rule had no seam and `ViewPayload` deliberately exposed no numeric
/// accessor at all. A responsive chart cannot avoid this: the backend cannot
/// know the pixel width it will be laid out in, so the value-to-pixel mapping
/// has to happen here. ADR-L D-14 records the decision.
///
/// **What it must never do.** The result is geometry. It never reaches a
/// `Text`, is never re-formatted, and is never used to derive a figure a
/// human reads — every one of those arrives already formatted (N-1, N-2,
/// N-4). A `double` also cannot round-trip the backend's full decimal
/// precision, which is exactly why it is confined to positions on a canvas
/// where a fraction of a pixel is invisible.
double rawDecimal(String path, String raw) {
  final value = double.tryParse(raw);
  if (value == null) {
    throw PayloadContractException(ContractFailure(path, 'a decimal string'));
  }
  return value;
}
