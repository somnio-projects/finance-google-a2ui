import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The round arrow at either end of the rail: the chip's own colours, a
/// hairline border and a whisper of elevation so it reads as a control.
class RailArrow extends StatelessWidget {
  /// Creates the arrow.
  const RailArrow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  /// The glyph.
  final IconData icon;

  /// What the button is called.
  final String label;

  /// Scrolls one step.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: tokens.chip,
        shape: CircleBorder(side: BorderSide(color: tokens.chipBorder)),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 22, color: tokens.chipText),
          ),
        ),
      ),
    );
  }
}
