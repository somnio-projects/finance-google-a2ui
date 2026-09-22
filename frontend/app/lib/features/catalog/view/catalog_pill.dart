import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';

/// The mono pill of the header rows: 11/500, radius 8, padding 5×10.
class CatalogPill extends StatelessWidget {
  /// Creates a pill in the header's violet.
  const CatalogPill(this.label, {super.key}) : component = false;

  /// Creates the teal pill a detail page gives its component name.
  const CatalogPill.component(this.label, {super.key}) : component = true;

  /// The pill's words.
  final String label;

  /// Whether this is the teal component pill.
  final bool component;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: component ? tokens.componentPill : tokens.pill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
          color: component ? tokens.componentPillText : tokens.pillText,
        ),
      ),
    );
  }
}

/// The `.subtag` of the design: 10/600 mono, upper-case, 0.08 em tracking.
class CatalogSubtag extends StatelessWidget {
  /// Creates the label in [color].
  const CatalogSubtag(this.label, {required this.color, super.key});

  /// The words, upper-cased by the style rather than rewritten.
  final String label;

  /// The label's colour.
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
      letterSpacing: 0.8,
      color: color,
    ),
  );
}
