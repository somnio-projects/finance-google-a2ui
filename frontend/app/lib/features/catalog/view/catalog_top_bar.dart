import 'package:finance_app/features/catalog/view/catalog_back_control.dart';
import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The doc top bar: a back control, the gradient mark, `A2UI Finance
/// Catalog`, and the `docs / components` crumb — with the component name in
/// the accent on a detail page, where the crumb is also a way back.
///
/// **Why the back control exists.** The catalog's two routes sit OUTSIDE the
/// `StatefulShellRoute`, so neither inherits the tab bar (`app_router.dart`).
/// That is deliberate — a documentation surface is not a tab — but it left
/// the index with no way back to the app at all, and the detail page with
/// only an 11 px monospace crumb that does not look like a control. On the
/// web the browser's back button hides this; in the app it is a dead end,
/// and the TL hit it from both pages.
///
/// Where it goes is the page's own answer, not `pop()`: the catalog is
/// reachable from the Home chip and from a Holdings card, so the stack
/// underneath is not always what a reader means by "back". The index returns
/// to Home and a detail page returns to the index — the same destination the
/// crumb names, so the two controls cannot disagree.
class CatalogTopBar extends StatelessWidget {
  /// Creates the bar; [component] is null on the index.
  const CatalogTopBar({this.component, super.key});

  /// The bar's title, the design's words.
  static const String title = 'A2UI Finance Catalog';

  /// The crumb's fixed half.
  static const String crumb = 'docs / components';

  /// What the back control announces on the index.
  static const String backToApp = 'Back to the app';

  /// What it announces on a component's page.
  static const String backToIndex = 'Back to the catalog';

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
    return PinnedHeader(
      color: tokens.topBar,
      border: Border(bottom: BorderSide(color: tokens.topBarBorder)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        child: Row(
          children: <Widget>[
            CatalogBackControl(
              label: component == null ? backToApp : backToIndex,
              destination: component == null
                  ? AppRoutes.home
                  : AppRoutes.catalog,
            ),
            const SizedBox(width: 10),
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
            // Flexible, and the title above is `Expanded`: the crumb is the
            // part that gives way on a narrow bar. It was fixed-width text and
            // the bar overflowed by 57 px the moment the back control was
            // added beside it — the row had no slack and nothing in it was
            // allowed to shrink.
            Flexible(
              child: GestureDetector(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
