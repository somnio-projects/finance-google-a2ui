import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// A list that has not arrived: [count] shimmer blocks of the same height,
/// stacked with the gap the real rows are stacked with.
///
/// The one shape spec frontend/0015 did not need and every list in the app
/// does — the Holdings position rows, the Holdings class rows, the Activity
/// timeline, the gallery's cards. It is a composition of [SkeletonShimmer]
/// and adds no motion of its own, so reduced motion is inherited (0020 OD-7).
///
/// It prints nothing. A row placeholder that carried a word or a figure would
/// be a value this client invented (N-3, N-9).
class SkeletonRows extends StatelessWidget {
  /// Stacks [count] blocks of [height], [gap] apart.
  const SkeletonRows({
    required this.count,
    required this.height,
    this.gap = 10,
    this.radius = 14,
    super.key,
  });

  /// How many blocks stand in for rows.
  final int count;

  /// One block's height — the real row's, so nothing reflows when it lands.
  final double height;

  /// The space between two blocks.
  final double gap;

  /// The blocks' corner radius; the tiles' 14 by default.
  final double radius;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var index = 0; index < count; index++)
        Padding(
          padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : gap),
          child: SkeletonShimmer(height: height, radius: radius),
        ),
    ],
  );
}
