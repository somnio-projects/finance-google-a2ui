import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// What the chart draws for the one step the reader has tapped.
///
/// The UI Kit's selected state is three things at once — a tinted column
/// behind the band, a deepened fill on the bar itself and a bold axis label —
/// and none of them is the dashed ring the first build drew (spec
/// frontend/0028 OD-3). They travel together in one value so a chart cannot
/// be handed half a selection.
///
/// The colours arrive from the component's own palette. Nothing here names a
/// `Color`: a chart is drawn in whatever the surface above it measured.
class WaterfallSelection extends Equatable {
  /// Creates a selection of the step at [index].
  const WaterfallSelection({
    required this.index,
    required this.barFill,
    required this.column,
  });

  /// The step drawn as selected, as a position in the walk.
  final int index;

  /// The fill the selected bar takes instead of its own mark — deeper in
  /// light, brighter in dark, and always still a gain or a loss colour, so
  /// selecting a bar never changes what its direction says.
  final Color barFill;

  /// The tint behind the whole band, which is what makes the selection
  /// readable at a glance from across a demo room.
  final Color column;

  @override
  List<Object?> get props => <Object?>[index, barFill, column];
}
