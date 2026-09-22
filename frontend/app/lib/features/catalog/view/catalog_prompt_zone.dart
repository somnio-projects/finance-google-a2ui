import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/features/catalog/view/catalog_zone_label.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Zone 3: the lines the system prompt carries for this view, verbatim.
///
/// The text is the entry's `prompt`, which is the fragment
/// `presentation/prompt.py` composes for the model — what the agent is
/// taught, not a paraphrase of it (spec backend/0034).
class CatalogPromptZone extends StatelessWidget {
  /// Creates the zone for [entry].
  const CatalogPromptZone({required this.entry, super.key});

  /// The zone's words.
  static const String label = 'Zone 3 · Prompt fragment';

  /// The panel's subtag.
  static const String injected = 'Injected into system prompt';

  /// The page's entry.
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final zones = CatalogTokens.of(context).zones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const CatalogZoneLabel(label),
        const SizedBox(height: 14),
        // The design's 3px accent is a left border; Flutter cannot round a
        // non-uniform border, so the accent is a strip inside the clip.
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: zones.prompt,
            border: Border.all(color: zones.promptBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 3, color: zones.promptAccent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CatalogSubtag(injected, color: zones.promptLabel),
                        const SizedBox(height: 8),
                        Text(
                          entry.prompt,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.65,
                            fontFamily: 'monospace',
                            color: zones.promptText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
