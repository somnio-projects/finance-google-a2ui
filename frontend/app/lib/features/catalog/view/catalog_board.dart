import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';

/// The 1024-point board every catalog page is drawn on (spec 0013 §2).
///
/// Centred and capped at the design's width; narrower viewports get the same
/// column at their own width, so a phone reads the catalog one card deep.
class CatalogBoard extends StatelessWidget {
  /// Creates the board around [children].
  const CatalogBoard({required this.children, super.key});

  /// The design's artboard width.
  static const double maxWidth = 1024;

  /// The rows of the page, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return ColoredBox(
      color: tokens.board,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: EdgeInsets.zero, children: children),
        ),
      ),
    );
  }
}

/// The catalog's failure state: the backend's own sentence, centred.
class CatalogFailure extends StatelessWidget {
  /// Creates the state.
  const CatalogFailure({required this.message, super.key});

  /// The failure's words, verbatim — the backend's safe `detail`, never a
  /// stack trace or a library message.
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: CatalogTokens.of(context).body),
      ),
    ),
  );
}
