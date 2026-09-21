import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';

/// The Home card's gain block, as `HoldingsSummary` example prints it.
const AllocationGain allTimeGain = AllocationGain(
  amountDisplay: r'+$61,204',
  percentDisplay: '+14.5%',
  trend: 'up',
  period: 'all-time',
);

/// The four asset classes of `Home.dc.html`, with day changes.
AllocationData byClass({
  AllocationGain? gain = allTimeGain,
  bool headline = true,
}) => AllocationData(
  title: 'Holdings & allocation',
  totalLabel: 'Total value',
  totalDisplay: r'$482,915.20',
  groupBy: 'asset_class',
  centerCount: '4',
  centerUnit: 'Classes',
  totalGain: gain,
  headline: headline,
  categories: const <AllocationCategory>[
    AllocationCategory(
      key: 'equities',
      label: 'Equities',
      valueDisplay: r'$289,430',
      weightDisplay: '59.9%',
      weight: 0.599,
      changeDisplay: '+0.9%',
      trend: 'up',
    ),
    AllocationCategory(
      key: 'bonds',
      label: 'Bonds',
      valueDisplay: r'$96,240',
      weightDisplay: '19.9%',
      weight: 0.199,
      changeDisplay: '-0.2%',
      trend: 'down',
    ),
    AllocationCategory(
      key: 'cash',
      label: 'Cash',
      valueDisplay: r'$38,633',
      weightDisplay: '8.0%',
      weight: 0.08,
      changeDisplay: '0.0%',
    ),
    AllocationCategory(
      key: 'alternatives',
      label: 'Alternatives',
      valueDisplay: r'$58,612',
      weightDisplay: '12.1%',
      weight: 0.121,
      changeDisplay: '+1.4%',
      trend: 'up',
    ),
  ],
);
