import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';

/// The index's page header: eyebrow, title, one paragraph and the pills.
///
/// These words are the app's own chrome — the backend serves no title for
/// the catalog as a whole. The design's paragraph counts *six* components and
/// names an *ADK* backend; the count is the backend's to state (it serves as
/// many entries as it registers) and the backend is FastAPI, so neither word
/// is printed (spec 0016 OD-3).
class CatalogHeader extends StatelessWidget {
  /// Creates the header.
  const CatalogHeader({super.key});

  /// The eyebrow.
  static const String eyebrow = 'COMPONENT GALLERY';

  /// The title.
  static const String title = 'Finance component catalog';

  /// The paragraph under it.
  static const String lede =
      'The components the agent can compose. The agent can only render what '
      'is declared here — this catalog is the contract between the Flutter '
      'client and the backend.';

  /// The pills: the API version and the licence, both facts of this
  /// repository. The design's `A2UI v1.0` is a protocol version nothing here
  /// serves, so it is not claimed (spec 0016 OD-3).
  static const List<String> pills = <String>['Catalog v1', 'Apache 2.0'];

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              letterSpacing: 0.66,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              letterSpacing: -0.5,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lede,
            style: TextStyle(fontSize: 14, height: 1.6, color: tokens.body),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[for (final pill in pills) CatalogPill(pill)],
          ),
        ],
      ),
    );
  }
}
