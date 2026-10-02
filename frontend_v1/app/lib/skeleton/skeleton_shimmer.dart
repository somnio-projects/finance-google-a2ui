import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';

/// A block that is still loading: the design's `.sk` / `.shim` — a resting
/// grey with a lighter band sweeping left to right every 1.4 s.
///
/// Sized by its caller, like the CSS it copies. When the platform asks for
/// reduced motion the band stops mid-sweep; the block still reads as a
/// placeholder, it just does not move.
class SkeletonShimmer extends StatefulWidget {
  /// Creates the block. [width] `null` fills the parent.
  const SkeletonShimmer({
    required this.height,
    this.width,
    this.radius = 7,
    this.shape = BoxShape.rectangle,
    this.child,
    super.key,
  });

  /// One sweep, from the artboards' `animation: shim 1.4s`.
  static const Duration period = Duration(milliseconds: 1400);

  /// The block's height.
  final double height;

  /// The block's width; `null` stretches to the parent.
  final double? width;

  /// Corner radius; ignored for a circle.
  final double radius;

  /// A rectangle, or a circle for a ring or an avatar.
  final BoxShape shape;

  /// Drawn over the shimmer — a donut's hole, for one.
  final Widget? child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: SkeletonShimmer.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SkeletonTokens.of(context);
    return AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) {
        // The band spans two box widths and travels four: off the left edge
        // at 0, centred at 0.5, off the right edge at 1 — the CSS's
        // `background-size: 400px; background-position: -200px → 400px`.
        final offset = -3 + 4 * _sweep.value;
        return Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(offset, 0),
              end: Alignment(offset + 2, 0),
              colors: <Color>[
                tokens.shimmerBase,
                tokens.shimmerHighlight,
                tokens.shimmerBase,
              ],
            ),
          ),
          child: child,
        );
      },
    );
  }
}
