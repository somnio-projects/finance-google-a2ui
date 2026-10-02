import 'allocation_groups_example.dart';

/// The `holdings.allocation.v1` example, **verbatim** from the backend's
/// generated catalog (`docs/catalog/view-catalog.snapshot.json`).
///
/// It is a **fixture, not a contract**. The contract is that file; this is a
/// copy, and `catalog_contract_test.dart` is what keeps the copy honest.
/// Regenerated with the crypto portfolio of spec `backend/0044`.
const Map<String, dynamic> holdingsAllocationExample = <String, dynamic>{
  // The grouping toggle's segments (GGU-145), in their own file. A fixture
  // missing them renders the contract error instead of the card, which is
  // how this copy announced itself when `groups` was added.
  'groups': allocationGroupsExample,
  'categories': <Map<String, dynamic>>[
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '+3.7%',
        'value': '0.03662471765085511455308163924',
      },
      'key': 'BTC',
      'label': 'Bitcoin',
      'trend': 'up',
      'value': <String, dynamic>{
        'amount': '134925.0000000000',
        'display': r'$134,925.00',
      },
      'weight': <String, dynamic>{
        'display': '27.94%',
        'value': '0.2793968796177879677425767505',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '+1.1%',
        'value': '0.01104009296920395119116792562',
      },
      'key': 'ETH',
      'label': 'Ethereum',
      'trend': 'up',
      'value': <String, dynamic>{
        'amount': '104400.0000000000',
        'display': r'$104,400.00',
      },
      'weight': <String, dynamic>{
        'display': '21.62%',
        'value': '0.2161870241400560595317770076',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-2.8%',
        'value': '-0.02806122448979591836734693878',
      },
      'key': 'SOL',
      'label': 'Solana',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '57226.2000000000',
        'display': r'$57,226.20',
      },
      'weight': <String, dynamic>{
        'display': '11.85%',
        'value': '0.1185015505827938321262200900',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{'display': '0.0%', 'value': '0'},
      'key': 'USDC',
      'label': 'USD Coin',
      'trend': 'flat',
      'value': <String, dynamic>{
        'amount': '51764.0000000000',
        'display': r'$51,764.00',
      },
      'weight': <String, dynamic>{
        'display': '10.72%',
        'value': '0.1071906620458415887509856803',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-2.4%',
        'value': '-0.02375809935205183585313174946',
      },
      'key': 'LINK',
      'label': 'Chainlink',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '47460.0000000000',
        'display': r'$47,460.00',
      },
      'weight': <String, dynamic>{
        'display': '9.83%',
        'value': '0.09827812419240479487910092704',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-1.0%',
        'value': '-0.01020857292953387002882253553',
      },
      'key': 'other',
      'label': 'Other',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '87140.000000000000',
        'display': r'$87,140.00',
      },
      'weight': <String, dynamic>{
        'display': '18.04%',
        'value': '0.1804457594211157569693395445',
      },
    },
  ],
  'center': <String, dynamic>{'count': '7', 'unit': 'Holdings'},
  'group_by': 'holding',
  'title': 'Allocation by holding',
  'total': <String, dynamic>{
    'amount': <String, dynamic>{
      'amount': '482915.200000000000',
      'display': r'$482,915.20',
    },
    'label': 'Total market value',
  },
  'total_gain': <String, dynamic>{
    'amount': <String, dynamic>{
      'amount': '61204.050000000000',
      'display': r'+$61,204',
    },
    'percent': <String, dynamic>{
      'display': '+14.5%',
      'value': '0.1451326340316114477883736297',
    },
    'period': 'all-time',
    'trend': 'up',
  },
  'view': 'holdings.allocation.v1',
};
