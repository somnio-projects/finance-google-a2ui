import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// The 64px logo tile, `Portfolio companion` and the one-line pitch.
class SignInHero extends StatelessWidget {
  /// Creates the hero.
  const SignInHero({super.key});

  /// The title the design prints.
  static const String title = 'Portfolio companion';

  /// The pitch the design prints.
  static const String pitch =
      'Ask about your portfolio. Get answers as living UI, not walls of text.';

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: LoginTokens.logoGradient,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: LoginTokens.logoGlow,
                blurRadius: 20,
                spreadRadius: -6,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: _Mark()),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            height: 1.2,
            letterSpacing: -0.3,
            color: tokens.title,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            pitch,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: tokens.subtitle,
            ),
          ),
        ),
      ],
    );
  }
}

/// The design's mark: the top half of a ring over a stem.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 26,
    child: Stack(
      children: <Widget>[
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 0.55,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ),
        ),
        Positioned(
          left: 11,
          top: 11.4,
          child: Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}
