import 'package:finance_app/features/catalog/view/catalog_schema_lines.dart';
import 'package:finance_app/features/catalog/view/catalog_zone_label.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Zone 2: the served contract of the view — component, id, endpoints, the
/// field inventory and the declared actions — in the design's dark panel.
///
/// The design prints a hand-written `props` schema with camelCase names the
/// backend never emits (`weightPct`, `onSliceTap`). What is drawn instead is
/// the inventory `GET /v1/views` serves, so the panel is the contract the
/// client binds and cannot say otherwise (spec 0013 OD-4).
class CatalogSchemaZone extends StatelessWidget {
  /// Creates the zone for [entry].
  const CatalogSchemaZone({required this.entry, super.key});

  /// The zone's words.
  static const String label = 'Zone 2 · A2UI schema';

  /// The page's entry.
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    final zones = tokens.zones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const CatalogZoneLabel(label),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: zones.code,
            border: Border.all(color: zones.codeBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text.rich(
              TextSpan(children: CatalogSchemaLines(entry, zones).build()),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.65,
                fontFamily: 'monospace',
                color: zones.codeText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
