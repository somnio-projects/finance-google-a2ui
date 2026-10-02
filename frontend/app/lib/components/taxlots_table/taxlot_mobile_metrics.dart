import 'package:flutter/widgets.dart';

/// The distances the tax-lot card draws with **below
/// `TaxLotMetrics.stackBelow`**, measured from the UI Kit's phone artboards.
///
/// A separate table from `TaxLotMetrics` because it is a separate
/// measurement: the phone frame is not the desktop one scaled, it is a
/// different arrangement of the same six values (spec `frontend/0027` OD-7).
abstract final class TaxLotMobileMetrics {
  /// One lot's block height, from the artboard's 80 px rail.
  ///
  /// Fixed for the same reason the desktop row is: the artboard's blocks are
  /// a constant height and every cell in them is one line.
  static const double tileHeight = 80;

  /// The gap between two blocks — tighter than the table's, because the rail
  /// is what separates them here.
  static const double tileGap = 4;

  /// The inset from the rail to the date, and from the tick box to it: the
  /// date's ink begins 36 px after the rail's left edge, which is the rail,
  /// two 8 px gaps and the 16 px box.
  static const double railGap = 8;

  /// The gap under the first line, above the four-cell grid.
  static const double lineGap = 10;

  /// The gap between a caption and the figure under it.
  static const double captionGap = 3;

  /// The four cells' widths as flex weights: shares, cost basis, market
  /// value, gain/loss — the artboard's 67 / 83 / 82 / 60 on 292 px of
  /// content, rounded to the grid.
  static const List<int> cellFlex = <int>[64, 80, 78, 60];

  /// The gap between two of those cells.
  static const double cellGap = 8;

  /// The block's own padding, inside the rail.
  ///
  /// A getter rather than a `const`, for a mechanical reason worth stating:
  /// a class of nothing but compile-time constants emits no executable line,
  /// so Dart's lcov writes **no record at all** for the file and
  /// `tool/check_coverage.dart` reports it as one no test loads — which is
  /// exactly the hole that check exists to close, and it cannot tell this
  /// case from a genuinely untested file. `TaxLotMetrics` is over the line
  /// already because its radii are getters; this table needs one member that
  /// runs, and the padding is the one a caller would reasonably expect to be
  /// derived.
  static EdgeInsets get tilePadding => const EdgeInsets.symmetric(vertical: 10);
}
