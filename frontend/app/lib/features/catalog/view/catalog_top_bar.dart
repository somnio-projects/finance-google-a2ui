import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The doc top bar: the gradient mark, `A2UI Finance Catalog`, and the
/// `docs / components` crumb — with the component name in the accent on a
/// detail page, where the crumb is also the way back to the index.
class CatalogTopBar extends StatelessWidget {
  /// Creates the bar; [component] is null on the index.
  const CatalogTopBar({this.component, super.key});

  /// The bar's title, the design's words.
  static const String title = 'A2UI Finance Catalog';

  /// The crumb's fixed half.
  static const String crumb = 'docs / components';

  /// The component the page documents, or null on the index.
  final String? component;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    final crumbStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'monospace',
      color: component == null ? tokens.muted : tokens.quiet,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.topBar,
        border: Border(bottom: BorderSide(color: tokens.topBarBorder)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AssistantTokens.of(context).avatar,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
            ),
          ),
          GestureDetector(
            onTap: component == null
                ? null
                : () => context.go(AppRoutes.catalog),
            child: Text.rich(
              TextSpan(
                text: component == null ? crumb : '$crumb / ',
                children: <InlineSpan>[
                  if (component case final String name)
                    TextSpan(
                      text: name,
                      style: TextStyle(color: tokens.accent),
                    ),
                ],
              ),
              style: crumbStyle,
            ),
          ),
        ],
      ),
    );
  }
}
