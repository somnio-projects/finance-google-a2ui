import 'package:finance_app/skeleton/skeleton_caption.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// The hero's change line and sparkline while the range's figures are on the
/// way — the Home artboard's `First-run hero · sparkline loading` (L2): a
/// 150 × 18 shimmer where the change goes, the 52 px sparkline box shimmering,
/// and `Loading…` beside a turning ring.
///
/// The total above it stays: it is the figure the person already has. The
/// artboard's caption names the range in words (`last 30 days`); those words
/// are the backend's `change.period` and have not arrived yet, so the
/// caption says only that it is waiting (N-9).
class HomeHeroLoading extends StatelessWidget {
  /// Creates the block.
  const HomeHeroLoading({super.key});

  /// The caption.
  static const String caption = 'Loading…';

  /// The sparkline box's height, the same 52 the chart draws at.
  static const double sparkHeight = 52;

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SkeletonShimmer(width: 150, height: 18, radius: 6),
      SizedBox(height: 14),
      SkeletonShimmer(height: sparkHeight, radius: 10),
      SizedBox(height: 12),
      SkeletonCaption(text: caption),
    ],
  );
}
