import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The tabs' app bar as the design draws it: the title at 22/500 with two
/// quiet icons on the right (search, filter). The icons are affordances the
/// design shows and this build does not yet wire; they say so when tapped.
class TabAppBar extends StatelessWidget {
  /// Creates the bar.
  const TabAppBar({required this.title, super.key});

  /// The tab's title — the payload's, verbatim.
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.header,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: tokens.text,
                ),
              ),
            ),
            const _QuietIcon(icon: Icons.search_rounded, label: 'Search'),
            const _QuietIcon(icon: Icons.tune_rounded, label: 'Filter'),
          ],
        ),
      ),
    );
  }
}

class _QuietIcon extends StatelessWidget {
  const _QuietIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return IconButton(
      tooltip: label,
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label is not part of this preview yet.')),
      ),
      icon: Icon(icon, size: 22, color: tokens.segmentText),
    );
  }
}

/// The tab's failure state: the backend's sentence, centred.
class TabFailure extends StatelessWidget {
  /// Creates the state.
  const TabFailure({required this.message, super.key});

  /// The failure's words, verbatim.
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
