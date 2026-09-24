import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/home/view/catalog_chip.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The *Holdings & allocation* card: the catalog component in the shell's
/// card chrome (spec 0026 §2).
///
/// The design labels this card `Catalog` because it **is** the
/// `HoldingsSummary` component, drawn by the same registered widget the
/// assistant would compose. The card, its title row and the chip are the
/// shell's; what is inside is the component's, reached through the registry
/// so this file never names its payload shape.
class HomeAllocationCard extends StatelessWidget {
  /// Creates the card.
  const HomeAllocationCard({required this.payload, super.key});

  /// `holdings.allocation.v1`, grouped by asset class.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    payload.text('title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                ),
                const CatalogChip(),
              ],
            ),
            const SizedBox(height: 14),
            ComponentHost(
              registry: context.read<ComponentRegistry>(),
              payload: payload,
            ),
          ],
        ),
      ),
    );
  }
}
