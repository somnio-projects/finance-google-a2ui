import 'package:finance_app/theme/activity_tokens.dart';
import 'package:flutter/material.dart';

/// The tax-lot badge beside a sell's caption: amber for a short-term gain,
/// teal for a long-term one. The words are the backend's (`term.label`); the
/// client only picks the colour from `term.term` (spec frontend/0009 §2).
class ActivityTermBadge extends StatelessWidget {
  /// Creates the badge.
  const ActivityTermBadge({required this.label, required this.term, super.key});

  /// `term.label`, verbatim.
  final String label;

  /// `term.term`: `short` or `long`.
  final String term;

  @override
  Widget build(BuildContext context) {
    final activity = ActivityTokens.of(context);
    final long = term == 'long';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: long ? activity.longBadge : activity.shortBadge,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: long ? activity.longBadgeText : activity.shortBadgeText,
        ),
      ),
    );
  }
}
