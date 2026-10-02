import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/turn_failure_notice.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Why the last turn failed, and the one thing to do about it (GGU-111).
///
/// A sentence a person can act on — see [turnFailureNotice] — and a *Try
/// again* that sends the last request once more through the bloc, so the
/// retry is the same code path as the turn that failed and not a second one.
/// The composer under it stays enabled and the chips above it stay tappable:
/// a failed turn is an idle Assistant with something to say, not a locked one.
class TurnFailureCard extends StatelessWidget {
  /// Creates the card for [failure].
  const TurnFailureCard({required this.failure, super.key});

  /// The backend's own safe code and message, or null when the turn ended
  /// `failed` without saying why.
  final AgentFailed? failure;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 20, color: tokens.loss),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                turnFailureNotice(failure),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: tokens.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => context.read<ConversationBloc>().add(
                const ConversationRetried(),
              ),
              style: TextButton.styleFrom(
                foregroundColor: tokens.accent,
                shape: const StadiumBorder(),
              ),
              child: const Text(turnRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
