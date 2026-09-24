import 'package:flutter/material.dart';

/// The payoff page's `.skel` motion: whatever it wraps breathes between full
/// and just over half opacity, ease-in-out, 1.4 s a cycle.
///
/// The flat bars and the dashed line it wraps are drawn in
/// `SkeletonTokens.bar`; this only fades them. Under reduced motion it holds
/// still at full opacity.
class SkeletonPulse extends StatefulWidget {
  /// Wraps [child].
  const SkeletonPulse({required this.child, super.key});

  /// One breath in or out.
  static const Duration period = Duration(milliseconds: 700);

  /// The faintest the child gets.
  static const double floor = 0.55;

  /// What pulses.
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: SkeletonPulse.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 0;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 1,
      end: SkeletonPulse.floor,
    ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
