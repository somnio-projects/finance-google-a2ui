import 'package:finance_views_repository/finance_views_repository.dart';

/// The `holdings.allocation.v1` example, **verbatim** from the backend's
/// generated catalog (`docs/catalog/view-catalog.snapshot.json`, PR #45).
///
/// It is a **fixture, not a contract**. The contract is that file; this is a
/// copy, and a copy of a generated artefact is the thing that goes stale.
/// Spec `frontend/0001` OD-1 carries the follow-up that replaces it with a
/// read of the snapshot once PR #45 is on `develop`.
///
/// Verified against snapshot digest `7c827ee9a8b8`
/// (16 declared fields, component `HoldingsSummary`).
const Map<String, dynamic> holdingsAllocationExample = <String, dynamic>{
  'categories': <Map<String, dynamic>>[
    <String, dynamic>{
      'key': 'BTC',
      'label': 'Bitcoin',
      'value': <String, dynamic>{
        'amount': '38550.000000',
        'display': r'$38,550.00',
      },
      'weight': <String, dynamic>{
        'display': '59.27%',
        'value': '0.5927249356535964796290203049',
      },
    },
    <String, dynamic>{
      'key': 'ETH',
      'label': 'Ethereum',
      'value': <String, dynamic>{
        'amount': '15902.500000',
        'display': r'$15,902.50',
      },
      'weight': <String, dynamic>{
        'display': '24.45%',
        'value': '0.2445086456350536450661607107',
      },
    },
    <String, dynamic>{
      'key': 'SOL',
      'label': 'Solana',
      'value': <String, dynamic>{
        'amount': '6096.000000',
        'display': r'$6,096.00',
      },
      'weight': <String, dynamic>{
        'display': '9.37%',
        'value': '0.09372895480530023708997426144',
      },
    },
    <String, dynamic>{
      'key': 'LINK',
      'label': 'Chainlink',
      'value': <String, dynamic>{
        'amount': '2962.500000',
        'display': r'$2,962.50',
      },
      'weight': <String, dynamic>{
        'display': '4.55%',
        'value': '0.04554987345976081895981770825',
      },
    },
    <String, dynamic>{
      'key': 'DOGE',
      'label': 'Dogecoin',
      'value': <String, dynamic>{
        'amount': '1527.600000000000',
        'display': r'$1,527.60',
      },
      'weight': <String, dynamic>{
        'display': '2.35%',
        'value': '0.02348759044628881925502701473',
      },
    },
  ],
  'title': 'Allocation by holding',
  'total': <String, dynamic>{
    'amount': <String, dynamic>{
      'amount': '65038.600000000000',
      'display': r'$65,038.60',
    },
    'label': 'Total market value',
  },
  'view': 'holdings.allocation.v1',
};

/// The example payload, parsed.
ViewPayload holdingsAllocationPayload() =>
    ViewPayload.fromJson(holdingsAllocationExample);

/// An envelope carrying [holdingsAllocationExample].
///
/// [extraViews] adds further entries, which is how a test reaches the
/// multi-surface layout the single-view fixture never exercises.
RenderedViews renderedViews({
  String? etag,
  Map<String, dynamic> extraViews = const <String, dynamic>{},
}) => RenderedViews.fromJson(<String, dynamic>{
  'as_of': '2026-09-20T00:00:00Z',
  'portfolio_id': 'current',
  'views': <String, dynamic>{
    'holdings.allocation.v1': holdingsAllocationExample,
    ...extraViews,
  },
}, etag: etag);
