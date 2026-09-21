import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';

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
  long,
}

/// Which way a lot's gain/loss points.
///
/// Taken from the payload's `trend` enum and never from the sign of a
/// display string: the sign is baked into `"+$8,925.00"`, and reading it
/// back out would be the client deriving a fact the backend already stated
/// (N-1, N-3).
enum TaxLotTrend {
  /// The backend's `trend: "up"`.
  up,

  /// The backend's `trend: "down"`.
  down,
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
