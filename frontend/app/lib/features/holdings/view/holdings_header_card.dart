import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/component_skeleton_host.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_toggle.dart';
import 'package:finance_app/features/home/view/catalog_chip.dart';
import 'package:finance_app/skeleton/skeleton_switcher.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The expanded allocation card: `Total value`, the all-time gain, the
/// `Catalog` chip, the class/sector toggle and the ring (spec frontend/0009).
///
/// While a regrouping is in flight the header and the toggle stay put and
/// only the ring gives way to the component's own skeleton: the pill the
/// person tapped must not be the thing that disappears, and the ring below it
/// is the only part `group_by` governs (spec frontend/0020 OD-3).
class HoldingsHeaderCard extends StatelessWidget {
  /// Creates the card.
  const HoldingsHeaderCard({
    required this.positions,
    required this.allocation,
    required this.groupBy,
    required this.onGroupBy,
    this.loading = false,
    super.key,
  });

  /// `holdings.positions.v1` — the header's figures.
  final ViewPayload positions;

  /// `holdings.allocation.v1` — the ring and its rows.
  final ViewPayload allocation;

  /// The grouping in force.
  final String groupBy;

  /// Called with the declared `group_by` value of the tapped pill.
  final ValueChanged<String> onGroupBy;

  /// Whether a new grouping's ring is still on the way.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final trend = positions.text('gain.trend');
    final tone = switch (trend) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.muted,
    };
    final glyph = switch (trend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    final gain = positions.text('gain.amount.display');
    final percent = positions.text('gain.percent.display');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        positions.text('total.label'),
                        style: TextStyle(fontSize: 12, color: tokens.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        positions.text('total.amount.display'),
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.1,
                          letterSpacing: -0.5,
                          color: tokens.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '$glyph $gain · $percent ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: tone,
                              ),
                            ),
                            TextSpan(
                              text: positions.text('gain.period'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const CatalogChip(),
              ],
            ),
            const SizedBox(height: 16),
            HoldingsToggle(selected: groupBy, onSelected: onGroupBy),
            const SizedBox(height: 16),
            SkeletonSwitcher(
              loading: loading,
              skeleton: ComponentSkeletonHost(
                registry: context.read<ComponentRegistry>(),
                view: HoldingsBloc.allocationView,
              ),
              child: ComponentHost(
                registry: context.read<ComponentRegistry>(),
                payload: allocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
