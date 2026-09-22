import 'package:flutter/material.dart';

/// The composer's 46 px circular control (spec frontend/0011 §2).
///
/// Extracted from `assistant_composer.dart` when the mic gained states of its
/// own (spec frontend/0023): the two buttons are the same shape and the shape
/// is now built from two files, which is the point at which a private class
/// stops being private.
class ComposerRoundButton extends StatelessWidget {
  /// Creates a round composer control.
  const ComposerRoundButton({
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.child,
    super.key,
  });

  /// The circle's fill.
  final Color color;

  /// What the control announces — read by a screen reader, and the handle
  /// every widget test in this feature takes hold of.
  final String tooltip;

  /// What a tap does. Null greys the control out of the tap sequence.
  final VoidCallback? onTap;

  /// The glyph at its centre.
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const CircleBorder(),
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    ),
  );
}
