import 'package:finance_charts/finance_charts.dart';

/// A walk for the chart suites, taken from the backend's own example.
///
/// These are the levels and display strings of `attribution.waterfall.v1`'s
/// rendered example — the opening cost basis, five contributions, the closing
/// market value. The component suite reads the *generated snapshot*; these
/// suites only need a plausible walk, and a literal keeps them free of file
/// I/O and fast.
const List<WaterfallStep> harnessSteps = <WaterfallStep>[
  WaterfallStep(key: ':start', kind: WaterfallStepKind.start, level: 56925),
  WaterfallStep(key: 'BTC', kind: WaterfallStepKind.gain, level: 67155),
  WaterfallStep(key: 'ETH', kind: WaterfallStepKind.loss, level: 64357.5),
  WaterfallStep(key: 'SOL', kind: WaterfallStepKind.gain, level: 65853.5),
  WaterfallStep(key: 'LINK', kind: WaterfallStepKind.loss, level: 65191),
  WaterfallStep(key: 'DOGE', kind: WaterfallStepKind.loss, level: 65038.6),
  WaterfallStep(key: ':end', kind: WaterfallStepKind.total, level: 65038.6),
];

/// The figure drawn above each bar, pre-formatted by the backend.
const List<String> harnessValueDisplays = <String>[
  r'$56,925.00',
  r'$10,230.00',
  r'-$2,797.50',
  r'$1,496.00',
  r'-$662.50',
  r'-$152.40',
  r'$65,038.60',
];

/// The category name under each band.
const List<String> harnessAxisLabels = <String>[
  'Cost basis',
  'Bitcoin',
  'Ethereum',
  'Solana',
  'Chainlink',
  'Dogecoin',
  'Market value',
];
