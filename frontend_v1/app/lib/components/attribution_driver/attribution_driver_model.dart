import 'package:equatable/equatable.dart';

/// Which way a figure moved, as the backend declared it (`up / down / flat`).
///
/// The card's glyphs and colours come from this and never from the sign of a
/// string (N-1). Its own enum rather than a chart kind: a contribution is not
/// a bar.
enum DriverTrend {
  /// A gain.
  up,

  /// A loss.
  down,

  /// No move; the backend prints no sign and the card draws no glyph.
  flat,
}

/// One of the card's three stat tiles, as Flow A's D2 state draws them.
///
/// Every string is the backend's: the label (*Price move*), the figure and
/// the line under it (*+$48.56*, *@ $1,204.66*, *of +$3,240.18*). The client
/// adds the trend glyph before a figure whose tile carries a [trend], and
/// nothing else (GGU-100, spec frontend/0014).
class DriverTile extends Equatable {
  /// Creates a tile.
  const DriverTile({
    required this.label,
    required this.figure,
    required this.caption,
    this.trend,
  });

  /// The tile's `label`.
  final String label;

  /// The big figure: a `*.display` string.
  final String figure;

  /// The line under the figure: a `*.display` string or a written caption.
  final String caption;

  /// The tile's `trend`, when the contract gives it one; null keeps the
  /// figure neutral and glyph-less.
  final DriverTrend? trend;

  @override
  List<Object?> get props => <Object?>[label, figure, caption, trend];
}

/// Everything `attribution.driver.v1` renders.
class AttributionDriverData extends Equatable {
  /// Creates the model.
  const AttributionDriverData({
    required this.symbol,
    required this.name,
    required this.caption,
    required this.contributionDisplay,
    required this.trend,
    required this.tiles,
  });

  /// The payload's `symbol`, drawn in the ticker chip.
  final String symbol;

  /// The payload's `name`.
  final String name;

  /// The payload's `caption`, e.g. *Top contributor today*.
  final String caption;

  /// The payload's `contribution.display`, sign included.
  final String contributionDisplay;

  /// The payload's `trend`, which colours the contribution.
  final DriverTrend trend;

  /// The three tiles, in the design's order: price move, holding, day share.
  final List<DriverTile> tiles;

  @override
  List<Object?> get props => <Object?>[
    symbol,
    name,
    caption,
    contributionDisplay,
    trend,
    tiles,
  ];
}
