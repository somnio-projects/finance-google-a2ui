import 'package:finance_app/features/catalog/view/catalog_thumbnail.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One gallery card: the live thumbnail, the component name, the backend's
/// summary, the view id as a mono badge and `View schema →`.
///
/// Every word but the arrow's is the entry's (spec 0013 OD-2): the design's
/// hand-written card titles have no backend field, so the title is the
/// component the client registers against.
class CatalogCard extends StatelessWidget {
  /// Creates the card for [entry].
  const CatalogCard({required this.entry, super.key});

  /// The link's words.
  static const String link = 'View schema →';

  /// The entry this card documents.
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Semantics(
      button: true,
      label: 'Open ${entry.component}',
      child: GestureDetector(
        onTap: () => context.go(catalogDetailRoute(entry.id)),
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: tokens.card,
            border: Border.all(color: tokens.cardBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.thumbnail,
                  border: Border(
                    bottom: BorderSide(color: tokens.thumbnailBorder),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: CatalogThumbnail(payload: entry.example),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.component,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: tokens.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          entry.summary,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: tokens.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(child: _Badge(entry.id)),
                          const SizedBox(width: 8),
                          Text(
                            link,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.badge,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            color: tokens.badgeText,
          ),
        ),
      ),
    );
  }
}
