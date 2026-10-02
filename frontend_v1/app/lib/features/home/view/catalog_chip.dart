import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The small `Catalog` chip a card wears when it is a catalog component;
/// tapping it opens the catalog index (spec frontend/0009 OD-5).
class CatalogChip extends StatelessWidget {
  /// Creates the chip.
  const CatalogChip({super.key});

  /// The chip's words.
  static const String label = 'Catalog';

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Semantics(
      button: true,
      label: 'Open the component catalog',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.catalog),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.catalogBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.catalogText,
            ),
          ),
        ),
      ),
    );
  }
}
