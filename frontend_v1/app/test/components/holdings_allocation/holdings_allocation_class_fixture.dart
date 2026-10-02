import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';

/// The Home card's gain block, as `HoldingsSummary` example prints it.
const AllocationGain allTimeGain = AllocationGain(
  amountDisplay: r'+$61,204',
  percentDisplay: '+14.5%',
  trend: 'up',
  period: 'all-time',
);

/// The five asset classes of the crypto portfolio (spec `backend/0044`), with
/// their day changes, in the taxonomy's own order.
///
/// The stablecoin row carries **no** trend at all, which is the fixture's job:
/// the glyph comes from the declared enum, so a row without one draws no line
/// rather than a client inferring one from the sign (N-2).
AllocationData byClass({
  AllocationGain? gain = allTimeGain,
  bool headline = true,
}) => AllocationData(
  title: 'Holdings & allocation',
  totalLabel: 'Total value',
  totalDisplay: r'$482,915.20',
  groupBy: 'asset_class',
  centerCount: '5',
  centerUnit: 'Classes',
  totalGain: gain,
  headline: headline,
  categories: const <AllocationCategory>[
    AllocationCategory(
      key: 'layer1',
      label: 'Layer 1',
      valueDisplay: r'$296,551',
      weightDisplay: '61.4%',
      weight: 0.614,
      changeDisplay: '+1.5%',
      trend: 'up',
    ),
    AllocationCategory(
      key: 'layer2',
      label: 'Layer 2',
      valueDisplay: r'$43,740',
      weightDisplay: '9.1%',
      weight: 0.091,
      changeDisplay: '+2.6%',
      trend: 'up',
    ),
    AllocationCategory(
      key: 'stablecoin',
      label: 'Stablecoins',
      valueDisplay: r'$51,764',
      weightDisplay: '10.7%',
      weight: 0.107,
      changeDisplay: '0.0%',
    ),
    AllocationCategory(
      key: 'defi',
      label: 'DeFi',
      valueDisplay: r'$43,400',
      weightDisplay: '9.0%',
      weight: 0.09,
      changeDisplay: '-4.4%',
      trend: 'down',
    ),
    AllocationCategory(
      key: 'infrastructure',
      label: 'Infrastructure',
      valueDisplay: r'$47,460',
      weightDisplay: '9.8%',
      weight: 0.098,
      changeDisplay: '-2.4%',
      trend: 'down',
    ),
  ],
);
