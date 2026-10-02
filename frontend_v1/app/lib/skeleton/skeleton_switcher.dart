import 'package:flutter/material.dart';

/// The swap between a skeleton and what replaces it, cross-faded rather than
/// cut (spec frontend/0020 OD-5, OD-9).
///
/// A skeleton that is correct and a payload that is correct still read as a
/// jolt when one is exchanged for the other in a single frame — which is the
/// half of the TL's report that is about motion rather than about the missing
/// placeholder. 180 ms of overlap is enough to read as one thing becoming
/// another and short enough not to read as a delay.
///
/// Under `MediaQuery.disableAnimations` the swap takes [Duration.zero]: the
/// new child is there immediately, which is the accessible behaviour and not
/// a degraded one (0020 OD-7).
class SkeletonSwitcher extends StatelessWidget {
  /// Shows [skeleton] while [loading], otherwise [child].
  const SkeletonSwitcher({
    required this.loading,
    required this.skeleton,
    required this.child,
    super.key,
  });

  /// One cross-fade.
  static const Duration period = Duration(milliseconds: 180);

  /// Whether the thing below is still on the way.
  final bool loading;

  /// The placeholder, drawn while [loading].
  final Widget skeleton;

  /// What arrives.
  final Widget child;

  /// Sizes the swap to the **incoming** child, not to the taller of the two.
  ///
  /// `AnimatedSwitcher`'s default stacks both and lets the `Stack` size to its
  /// largest child, so for the length of the fade the page is as tall as
  /// whichever of the skeleton and the payload is bigger, and then it jumps.
  /// That is a reflow, and "nothing reflows when the payload lands" is the
  /// claim OD-1 makes — a switcher that broke it would be undoing the thing
  /// it was added for. The outgoing child is `Positioned` instead, so it
  /// keeps the width, fades where it stood, and contributes no height.
  static Widget _sizeToIncoming(Widget? current, List<Widget> previous) =>
      Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          for (final outgoing in previous)
            Positioned(top: 0, left: 0, right: 0, child: outgoing),
          ?current,
        ],
      );

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : period,
    layoutBuilder: _sizeToIncoming,
    // Keyed by which of the two is showing, not by the widgets themselves:
    // a rebuild with the same phase must not restart the fade, and a payload
    // arriving must.
    child: KeyedSubtree(
      key: ValueKey<bool>(loading),
      child: loading ? skeleton : child,
    ),
  );
}
