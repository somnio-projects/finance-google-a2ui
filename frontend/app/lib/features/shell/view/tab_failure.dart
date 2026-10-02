import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The tab's failure state: the backend's sentence, and the way out of it.
///
/// It used to be the sentence alone, centred (spec frontend/0018), which is
/// an error state with no affordance — a reader who hit it could reload the
/// page or leave. `onRetry` re-issues the tab's first request through its
/// own bloc, so the retry is the same path as the load that failed and not a
/// second one (GGU-110 AC-1). The message stays verbatim: the backend's own
/// safe `detail`, never a library string (architecture rules §4).
class TabFailure extends StatelessWidget {
  /// Creates the state. [onRetry] null draws the sentence alone.
  const TabFailure({required this.message, this.onRetry, super.key});

  /// The control's words.
  static const String retryLabel = 'Try again';

  /// The failure's words, verbatim.
  final String message;

  /// Asks the tab to load again, or null when there is nothing to re-ask.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tokens.text),
            ),
            if (onRetry case final onRetry?) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.text,
                    side: BorderSide(color: tokens.segmentBorder),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(retryLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
