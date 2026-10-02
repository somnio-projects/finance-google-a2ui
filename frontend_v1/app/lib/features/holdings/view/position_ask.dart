import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The hand-off under an expanded position: the gradient dot, the caption
/// the backend wrote and a chevron. Tapping it opens the assistant with the
/// row's `ask.text` already sent (spec frontend/0009 OD-3).
class PositionAsk extends StatelessWidget {
  /// Creates the hand-off.
  const PositionAsk({required this.label, required this.question, super.key});

  /// `ask_label`, the caption.
  final String label;

  /// `ask.text`, the question the assistant receives verbatim.
  final String question;

  @override
  Widget build(BuildContext context) {
    final holdings = HoldingsTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go(askRoute(question)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: holdings.askFill),
            border: Border.all(color: holdings.askBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: HoldingsTokens.askIconGradient,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: holdings.askText,
                  ),
                ),
              ),
              Text(
                '›',
                style: TextStyle(fontSize: 18, color: holdings.askChevron),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
