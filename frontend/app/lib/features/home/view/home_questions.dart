import 'package:finance_app/features/home/view/home_questions_rail.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// *Suggested questions*: a heading with an indigo dot and a row of chips
/// that hands off to the assistant (spec 0026 OD-6).
///
/// Binds `questions_title` and `questions[].text`. The chips scroll
/// horizontally past the right edge, as the design's cut-off third chip
/// shows they do.
class HomeQuestions extends StatelessWidget {
  /// Creates the section.
  const HomeQuestions({required this.payload, super.key});

  /// `portfolio.summary.v1`.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                payload.text('questions_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HomeQuestionsRail(
          questions: <String>[
            for (final question in payload.rows('questions'))
              question.text('text'),
          ],
        ),
      ],
    );
  }
}

/// One suggested question: `💬` and the backend's words, tapping asks it.
class QuestionChip extends StatelessWidget {
  /// Creates the chip.
  const QuestionChip({required this.text, super.key});

  /// The question, verbatim.

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: tokens.chip,
      shape: StadiumBorder(side: BorderSide(color: tokens.chipBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.go(askRoute(text)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            '💬 $text',
            style: TextStyle(fontSize: 13, color: tokens.chipText),
          ),
        ),
      ),
    );
  }
}
