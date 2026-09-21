import 'package:equatable/equatable.dart';

/// A point in a painter's coordinate space, in logical pixels.
///
/// This package deliberately does not use `dart:ui`'s `Offset`: the whole
/// argument for keeping the geometry pure Dart is that it runs under
/// `dart test` without a Flutter engine (ADR-L D-13). The painter converts
/// these to `Offset` at the last moment, which is one line at one seam.
class ChartPoint extends Equatable {
  /// Creates a point.
  const ChartPoint(this.x, this.y);

  /// Distance from the left edge of the plot.
  final double x;

  /// Distance from the top edge of the plot. Larger is lower on screen, the
  /// same convention as the canvas.
  final double y;

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  String toString() => 'ChartPoint($x, $y)';
}

/// An axis-aligned rectangle in a painter's coordinate space.
///
/// Stored as edges rather than origin-plus-size because every waterfall bar is
/// naturally described by the two value levels it spans, and deriving the
/// height once here is better than at each call site.
class ChartRect extends Equatable {
  /// Creates a rectangle from its four edges.
  ///
  /// [top] is the smaller `y` — the visually higher edge — so a bar that runs
  /// from a lower value to a higher one still has `top < bottom`.
  const ChartRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Creates a rectangle spanning [a] to [b] vertically, in either order.
  ///
  /// A waterfall bar is bounded by two running totals and which of them is
  /// the higher one depends on the step's direction. Normalising here keeps
  /// that comparison out of the layout and out of the painter.
  factory ChartRect.between({
    required double left,
    required double right,
    required double a,
    required double b,
  }) => ChartRect(
    left: left,
    top: a < b ? a : b,
    right: right,
    bottom: a < b ? b : a,
  );

  /// The left edge.
  final double left;

  /// The upper edge (the smaller `y`).
  final double top;

  /// The right edge.
  final double right;

  /// The lower edge (the larger `y`).
  final double bottom;

  /// The horizontal extent.
  double get width => right - left;

  /// The vertical extent. Never negative — see [ChartRect.between].
  double get height => bottom - top;

  /// The midpoint of the upper edge, where a value label is anchored.
  ChartPoint get topCenter => ChartPoint((left + right) / 2, top);

  @override
  List<Object?> get props => <Object?>[left, top, right, bottom];

  @override
  String toString() => 'ChartRect($left, $top, $right, $bottom)';
}
