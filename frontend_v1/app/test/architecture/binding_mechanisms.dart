/// The mechanism lists the binding rules fail on.
///
/// Split out of `binding_rules_test.dart` so that file stays inside the
/// 150-line budget the gate enforces on tests too — the fix
/// `.claude/rules/frontend/testing.md` §3 prescribes.
library;

/// Everything that turns a number into text, or text into a number.
///
/// `double.parse` does **not** match `double.tryParse` as a substring, and the
/// `try*` forms are the ones a developer reaches for first — so both spellings
/// of all four are listed. A figure arrives pre-formatted (N-1); a figure is
/// never recomputed (N-2).
const List<String> numberMechanisms = <String>[
  'NumberFormat',
  'package:intl/',
  "import 'dart:math'",
  'toStringAsFixed',
  'toStringAsPrecision',
  'toStringAsExponential',
  'double.parse',
  'double.tryParse',
  'num.parse',
  'num.tryParse',
  'int.parse',
  'int.tryParse',
];

/// Every file allowed a number mechanism. Exactly one, and a test says so.
///
/// Kept as a set rather than a bare string so the count is a thing a test can
/// assert — the claim "the exemption set has exactly one member" appears in
/// ADR-L D-14, in two rule files and in `SECURITY.md`, and a claim repeated
/// in four places should be checked in one.
const Set<String> numberAllowed = <String>{geometrySeam};

/// The one file allowed a number mechanism, and why.
///
/// `rawDecimal` turns the contract's raw `amount` into a position on a
/// canvas, which is the use ADR-K reserves that member for. A responsive
/// chart cannot get its value-to-pixel mapping from a server that does not
/// know the width it will be laid out in (ADR-L D-14). The allowance is per
/// file, so that file is five lines long on purpose.
const String geometrySeam =
    'packages/finance_views_repository/lib/src/raw_decimal.dart';

/// Every way of asking the device what time it is (N-13).
const List<String> clockMechanisms = <String>[
  'DateTime.now(',
  'DateTime.timestamp(',
  'Stopwatch(',
];

/// Ways a server-supplied string could become code or a field path (N-5).
///
/// Both spellings of the decoder are listed. `dart:convert` exports the `json`
/// constant as well as the top-level function, so `json.decode(` is the same
/// mechanism written differently — needling only `jsonDecode(` was the same
/// near-miss shape as listing `double.parse` without `double.tryParse`.
const List<String> interpreterMechanisms = <String>[
  "import 'dart:mirrors'",
  'Function.apply(',
  'noSuchMethod(',
  'jsonDecode(',
  'json.decode(',
];
