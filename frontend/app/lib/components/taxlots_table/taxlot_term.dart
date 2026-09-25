import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/painting.dart';

/// Which holding-period bucket a lot falls in.
///
/// An enum rather than the payload's raw `"short"` / `"long"` string, so a
/// colour is chosen by matching a value the compiler knows about and a
/// `switch` over it is exhaustive. A third spelling is then a contract
/// violation raised by name rather than a row drawn in a default colour —
/// the same shape `WaterfallStepKind` gives the waterfall's directions.
enum TaxLotTerm {
  /// Held under a year — amber in the catalog's shared token legend.
  short,

  /// Held a year or more — teal.
  long;

  /// Maps the backend's `term` enum, raising on anything else.
  ///
  /// On the enum rather than in the component, for the reason
  /// [TaxLotTermPalette] gives: it is a question about a term, and the
  /// component that asks it is not the only thing that could. [path] is the
  /// payload path to name when the answer is not one of the two.
  static TaxLotTerm read(String raw, String path) => switch (raw) {
    'short' => TaxLotTerm.short,
    'long' => TaxLotTerm.long,
    _ => throw PayloadContractException(
      ContractFailure(path, 'either "short" or "long"'),
    ),
  };
}

/// Which way a signed figure points.
///
/// Taken from the payload's `trend` / `direction` enum and never from the sign
/// of a display string: the sign is baked into `"+$8,925.00"`, and reading it
/// back out would be the client deriving a fact the backend already stated
/// (N-1, N-3).
enum TaxLotTrend {
  /// The backend's `"up"`.
  up,

  /// The backend's `"down"`.
  down,

  /// The backend's `"flat"` — a figure that rounds to zero.
  ///
  /// Not a design state the kit draws; a state the **contract permits** and
  /// this client used to throw on. Both fields come from the backend's
  /// `trend_of`, which answers `"flat"` for a lot sold at exactly its basis,
  /// so rejecting it raised `PayloadContractException` on a payload that was
  /// never wrong (spec `backend/0049` OD-7).
  flat;

  /// Maps the backend's direction enum, raising on anything else.
  ///
  /// One reader for both callers — a row's `trend` and the footer total's
  /// `realized.direction` — because they are the same three tokens from the
  /// same backend helper. [path] is the payload path the failure names.
  static TaxLotTrend read(String raw, String path) => switch (raw) {
    'up' => TaxLotTrend.up,
    'down' => TaxLotTrend.down,
    'flat' => TaxLotTrend.flat,
    _ => throw PayloadContractException(
      ContractFailure(path, 'one of "up", "down" or "flat"'),
    ),
  };
}

/// The colour a signed figure is drawn in.
///
/// On the enum rather than in each widget, for the reason
/// [TaxLotTermPalette] gives: a row's gain/loss cell and the footer's total
/// ask the same question and only one of them is a row. `flat` takes the
/// primary text colour — the absence of a direction, not a third hue.
extension TaxLotTrendPalette on TaxLotTrend {
  /// The colour [palette] gives this direction.
  Color colorFor(TaxLotPalette palette) => switch (this) {
    TaxLotTrend.up => palette.gain,
    TaxLotTrend.down => palette.loss,
    TaxLotTrend.flat => palette.primaryText,
  };
}

/// The colours a term is drawn in.
///
/// The lookup belongs to the term rather than to a static on the row
/// widget: the legend, a row's rail and the footer's split pills all ask
/// the same question, and only one of them is a row. A `switch` over the
/// enum is exhaustive, so a third term added to the contract is a compile
/// error here rather than a pill drawn in whichever colour came last.
extension TaxLotTermPalette on TaxLotTerm {
  /// The four colours [palette] gives this term.
  TaxLotTermColors colorsIn(TaxLotPalette palette) => switch (this) {
    TaxLotTerm.short => palette.shortTerm,
    TaxLotTerm.long => palette.longTerm,
  };
}
