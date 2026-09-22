import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The agent's words, 14/400 in the text colour, verbatim (OD-1).
class AssistantAnswer extends StatelessWidget {
  /// Creates the answer.
  const AssistantAnswer({required this.text, super.key});

  /// What the backend wrote.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      height: 1.4,
      color: HomeTokens.of(context).text,
    ),
  );
}
