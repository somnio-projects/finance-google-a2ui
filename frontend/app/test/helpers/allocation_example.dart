/// The `holdings.allocation.v1` example, **verbatim** from the backend's
/// generated catalog (`docs/catalog/view-catalog.snapshot.json`).
///
/// It is a **fixture, not a contract**. The contract is that file; this is a
/// copy, and `catalog_contract_test.dart` is what keeps the copy honest.
/// Regenerated with the equities portfolio of spec `backend/0025`.
const Map<String, dynamic> holdingsAllocationExample = <String, dynamic>{
  'categories': <Map<String, dynamic>>[
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '+4.2%',
        'value': '0.04200328691289680823458178358',
      },
      'key': 'NVDA',
      'label': 'NVIDIA Corp',
      'trend': 'up',
      'value': <String, dynamic>{
        'amount': '108419.400000',
        'display': r'$108,419.40',
      },
      'weight': <String, dynamic>{
        'display': '22.45%',
        'value': '0.2245102245694482178237504224',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '+1.1%',
        'value': '0.01101283385362469649670482137',
      },
      'key': 'AAPL',
      'label': 'Apple Inc.',
      'trend': 'up',
      'value': <String, dynamic>{
        'amount': '69954.000000',
        'display': r'$69,954.00',
      },
      'weight': <String, dynamic>{
        'display': '14.49%',
        'value': '0.1448577307154548044874131110',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '+1.4%',
        'value': '0.01382488479262672811059907834',
      },
      'key': 'GLD',
      'label': 'SPDR Gold Shares',
      'trend': 'up',
      'value': <String, dynamic>{
        'amount': '49500.000000',
        'display': r'$49,500.00',
      },
      'weight': <String, dynamic>{
        'display': '10.25%',
        'value': '0.1025024683422679592607563398',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-0.1%',
        'value': '-0.0005198242049052502244695430273',
      },
      'key': 'MSFT',
      'label': 'Microsoft Corp',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '46530.000000',
        'display': r'$46,530.00',
      },
      'weight': <String, dynamic>{
        'display': '9.64%',
        'value': '0.09635232024173188170511095944',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-4.9%',
        'value': '-0.04864864864864864864864864865',
      },
      'key': 'VOO',
      'label': 'Vanguard S&P 500 ETF',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '44880.000000',
        'display': r'$44,880.00',
      },
      'weight': <String, dynamic>{
        'display': '9.29%',
        'value': '0.09293557129698961639641908145',
      },
    },
    <String, dynamic>{
      'change': <String, dynamic>{
        'display': '-0.2%',
        'value': '-0.001513426119213457764354390919',
      },
      'key': 'other',
      'label': 'Other',
      'trend': 'down',
      'value': <String, dynamic>{
        'amount': '163631.800000',
        'display': r'$163,631.80',
      },
      'weight': <String, dynamic>{
        'display': '33.88%',
        'value': '0.3388416848341075203265500858',
      },
    },
  ],
  'center': <String, dynamic>{'count': '14', 'unit': 'Holdings'},
  'group_by': 'holding',
  'title': 'Allocation by holding',
  'total': <String, dynamic>{
    'amount': <String, dynamic>{
      'amount': '482915.200000',
      'display': r'$482,915.20',
    },
    'label': 'Total market value',
  },
  'total_gain': <String, dynamic>{
    'amount': <String, dynamic>{
      'amount': '61204.050000',
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
