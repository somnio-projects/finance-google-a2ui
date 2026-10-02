import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure_tile.dart';
import 'package:flutter/material.dart';

/// The design's "Order impact" panel — the consequences of the order.
///
/// Measured from the catalog artboard at 1024, over HTTP so the bundle
/// actually boots: radius **14 px**, padding **13 × 15 px**, 1 px border.
/// In the recomputed state the **whole panel** carries the accent tint, and
/// that is the design's mark for "these figures moved".
///
/// Every figure here is a `*.display` string the backend formatted. This
/// widget decides *where* a figure sits and *whether it is marked*; it never
/// decides what it says. Which figures changed is decided upstream by
/// comparing display **strings** (spec 0006 AC-9) — never by arithmetic, so
/// the client still cannot know whether a figure went up.
class OrderTicketImpact extends StatelessWidget {
  /// Creates the panel.
  const OrderTicketImpact({
    required this.figures,
    required this.changedFigures,
    required this.isWide,
    super.key,
  });

  /// The panel's corner radius, measured from the design.
  static const double radius = 14;

  /// The panel's padding, measured from the design.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 15,
    vertical: 13,
  );

  /// The section caption, which the payload does not carry — it is the app's
  /// own chrome, like the app bar's title.
  static const String caption = 'Order impact';

  /// The figures, in the order the card shows them.
  final List<OrderTicketFigure> figures;

  /// Names of the figures to mark as changed.
  final Set<String> changedFigures;

  /// Whether there is room to lay the figures out side by side.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final isChanged = changedFigures.isNotEmpty;
    final tiles = <Widget>[
      for (final figure in figures)
        OrderTicketFigureTile(
          figure: figure,
          isChanged: changedFigures.contains(figure.name),
        ),
    ];
    return Semantics(
      container: true,
      label: isChanged ? '$caption, updated' : caption,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The design's measured `hlBg` / `hlBorder` are the accent this
          // palette already carries as `barTotal`, laid over the card at low
          // opacity — #eef0ff over #fdfbff in light, #20223a over #15161c in
          // dark. Deriving them keeps one accent in one place instead of
          // adding two near-duplicate roles to a shared enumeration.
          color: isChanged
              ? Color.alphaBlend(
                  palette.barTotal.withValues(alpha: 0.10),
                  palette.surface,
                )
              : palette.surface,
          border: Border.all(
            color: isChanged
                ? Color.alphaBlend(
                    palette.barTotal.withValues(alpha: 0.32),
                    palette.surface,
                  )
                : palette.border,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                caption.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.barTotal,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final tile in tiles) Expanded(child: tile),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final tile in tiles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: tile,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
