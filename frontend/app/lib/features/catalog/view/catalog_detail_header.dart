import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// A detail page's header: the component as the title, the backend's
/// summary under it, and three pills — the view id, `A2UI component`, and
/// the component in teal (spec 0016 OD-2).
class CatalogDetailHeader extends StatelessWidget {
  /// Creates the header for [entry].
  const CatalogDetailHeader({required this.entry, super.key});

  /// The middle pill's words.
  static const String kindPill = 'A2UI component';

  /// The page's entry.
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.component,
                style: TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: tokens.text,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                entry.summary,
                style: TextStyle(fontSize: 14, height: 1.5, color: tokens.body),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            CatalogPill(entry.id),
            const CatalogPill(kindPill),
            CatalogPill.component(entry.component),
          ],
        ),
      ],
    );
  }
}
