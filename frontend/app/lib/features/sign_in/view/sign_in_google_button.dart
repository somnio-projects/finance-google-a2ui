import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// `Continue with Google`: 52px, radius 26, a hairline border and the mark.
class SignInGoogleButton extends StatelessWidget {
  /// Creates the button.
  const SignInGoogleButton({
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  /// The words the design prints.
  static const String label = 'Continue with Google';

  /// Called on tap; ignored while [busy].
  final VoidCallback onPressed;

  /// Whether a request is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: tokens.googleFill,
          foregroundColor: tokens.googleText,
          disabledForegroundColor: tokens.googleText,
          side: BorderSide(color: tokens.googleBorder),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        icon: const SizedBox(width: 20, height: 20, child: GoogleMark()),
        label: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Google's four-colour `G`, painted: no asset, no dependency.
class GoogleMark extends StatelessWidget {
  /// Creates the mark.
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: GoogleMarkPainter());
}

/// Four arcs and a bar — the geometry of Google's mark.
class GoogleMarkPainter extends CustomPainter {
  /// Creates the painter.
  const GoogleMarkPainter();

  /// π, spelled out: `dart:math` is banned under `app/lib` (binding rules).
  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    // Google's brand colours, in the order `LoginTokens.googleMark` documents.
    // They used to be four private literals here, which made this widget file
    // one of five naming a `Color` while `frontend/CLAUDE.md` said only a
    // `*_tokens.dart` did (spec frontend/0029 OD-4).
    final [blue, red, yellow, green] = LoginTokens.googleMark;
    final stroke = size.width * 0.19;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Clockwise from the gap at the right: red (top), yellow (left),
    // green (bottom), blue (bottom-right up to the bar).
    canvas
      ..drawArc(inset, -_pi * 0.85, _pi * 0.6, false, paint..color = red)
      ..drawArc(inset, _pi * 0.75, _pi * 0.5, false, paint..color = yellow)
      ..drawArc(inset, _pi * 0.25, _pi * 0.5, false, paint..color = green)
      ..drawArc(inset, 0, _pi * 0.25, false, paint..color = blue)
      ..drawRect(
        Rect.fromLTWH(
          size.width / 2,
          size.height / 2 - stroke / 2,
          size.width / 2 - stroke / 3,
          stroke,
        ),
        Paint()..color = blue,
      );
  }

  @override
  bool shouldRepaint(GoogleMarkPainter oldDelegate) => false;
}
