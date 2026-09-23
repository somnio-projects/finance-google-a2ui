import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The Assistant's header, measured off the artboards (spec frontend/0011
/// §2): gradient avatar, `Assistant`, the `Gemini · A2UI` pill and the
/// `Simulated portfolio` badge. The words are the product's, not a
/// payload's.
///
/// **The badge says "portfolio", and the word is load-bearing.** It read
/// `Simulated` alone, sitting beside the pill that names the model — so it
/// said, to anyone reading left to right, that the *assistant* was
/// simulated. It is not: the turn above it is a real Gemini call against
/// real tools. What is simulated is the portfolio, which is what Home's
/// badge says in full, and Home's comes from the backend
/// (`summary_payload.badge`). This one stays a client string because this
/// header binds no payload (spec frontend/0011 §2 rules that deliberately),
/// so matching the backend's wording is the whole of the fix.
class AssistantHeader extends StatelessWidget {
  /// Creates the header.
  const AssistantHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final assistant = AssistantTokens.of(context);
    return PinnedHeader(
      color: tokens.header,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: <Widget>[
            const AssistantAvatar(size: 36, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Assistant',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: assistant.pill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Gemini · A2UI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: assistant.pillText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: assistant.badge,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: assistant.badgeDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Simulated portfolio',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: assistant.badgeText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The assistant's mark: a rounded square in the 135° indigo→violet gradient.
class AssistantAvatar extends StatelessWidget {
  /// Creates the avatar at [size] with [radius] corners.
  const AssistantAvatar({required this.size, required this.radius, super.key});

  /// Side, in logical pixels.
  final double size;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final assistant = AssistantTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: assistant.avatar,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
