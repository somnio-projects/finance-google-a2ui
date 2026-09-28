import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_empty.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header_row.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_layout.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// The `HoldingsSummary` card: header (unless a shell draws it), the ring
/// with its centre count, the legend, and the stacked bar (spec 0026 §2).
class HoldingsAllocationCard extends StatefulWidget {
  /// Creates the card.
  const HoldingsAllocationCard({
    required this.data,
    this.onGroupChanged,
    this.isBusy = false,
    this.initialSelectedIndex,
    super.key,
  });

  /// Corner radius.
  static const double radius = 16;

  /// Inner padding — the artboard's `Espaciado spacing/16`, all four sides.
  static const EdgeInsets padding = EdgeInsets.all(16);

  /// The gap between the header block and the body (`Espacio spacing/16`).
  static const double headerGap = 16;

  /// Gap between ring and legend.
  static const double chartGap = 22;

  /// Below this width the ring stacks above the legend, on the card that
  /// draws the total inside the ring.
  ///
  /// **The desktop artboard's own content width** (640 less `spacing/16`,
  /// twice). The design draws the ring *beside* the legend at 640 and *above*
  /// it at 360 — `DonutLegendRow` is `Flujo Vertical` on the mobile board —
  /// and nothing in between, so the honest rule is: take the horizontal
  /// arrangement only where the design was drawn horizontal. It was
  /// [shellStackBelowWidth] for both variants, which put the Assistant's
  /// ~374 pt column in the *desktop* branch and overflowed the ring with the
  /// total (GGU-145).
  static const double stackBelowWidth = 608;

  /// The same threshold on a card whose header a shell drew.
  ///
  /// **Deliberately left at its old value.** The Home and Holdings screens
  /// have not been re-measured against Figma, their ring holds a short count
  /// rather than a currency total, and moving them would be a visual change
  /// to two screens this ticket did not look at. Spec `frontend/0033` OD-7.
  static const double shellStackBelowWidth = 340;

  /// Ring size when a shell's card stacks — unchanged, for the reason
  /// [shellStackBelowWidth] gives.
  static const double shellStackedDiameter = 112;

  /// Ring size on the measured card — the mobile artboard's `Donut`,
  /// 160 × 160, at every width: the total lives in its hole, so shrinking it
  /// is what overflowed before.
  static const double stackedDiameter = 160;

  /// Ring size beside a legend when a shell draws the header — the Home
  /// card's 104. The catalog card keeps `DonutChart.designDiameter`.
  static const double compactDiameter = 104;

  /// The model.
  final AllocationData data;

  /// Called with a grouping's `value` when a segment is tapped, or null
  /// where no host can re-request — in which case no toggle is drawn.
  final ValueChanged<String>? onGroupChanged;

  /// True while the re-render a tap asked for is in flight.
  final bool isBusy;

  /// A slice to start selected, for goldens.
  final int? initialSelectedIndex;

  @override
  State<HoldingsAllocationCard> createState() => _HoldingsAllocationCardState();
}

class _HoldingsAllocationCardState extends State<HoldingsAllocationCard> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final data = widget.data;
    final body = data.isEmpty
        ? HoldingsAllocationEmpty(
            total: data.headline ? data.totalDisplay : null,
            label: data.totalLabel,
          )
        : LayoutBuilder(builder: _body);
    if (!data.headline) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(HoldingsAllocationCard.radius),
      ),
      child: Padding(
        padding: HoldingsAllocationCard.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            HoldingsAllocationHeaderRow(
              data: data,
              onGroupChanged: widget.onGroupChanged,
              isBusy: widget.isBusy,
            ),
            const SizedBox(height: HoldingsAllocationCard.headerGap),
            body,
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, BoxConstraints constraints) =>
      HoldingsAllocationLayout(
        data: widget.data,
        constraints: constraints,
        selectedIndex: _selectedIndex,
        onSelect: _select,
      );

  void _select(int index) =>
      setState(() => _selectedIndex = _selectedIndex == index ? null : index);
}
