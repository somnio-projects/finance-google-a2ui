import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fixtures.dart';

/// One `GET /v1/views` entry in the served shape (spec backend/0034).
///
/// A fixture, not a contract: the snapshot keys its entries by `view` where
/// the endpoint says `id`, so the suite cannot read it and this shape is
/// hand-written after the `ViewDescriptor` schema instead.
Map<String, dynamic> catalogEntryJson({
  String id = 'holdings.allocation.v1',
  Object? guidance = const <String, dynamic>{
    'use_when': 'the user asks what is held now',
    'avoid_when': 'why a value changed — `attribution.waterfall.v1`',
  },
}) => <String, dynamic>{
  'id': id,
  'summary': 'Allocation of the portfolio, by holding.',
  'component': 'HoldingsSummary',
  'endpoints': <String>[
    'GET /v1/portfolios/{portfolio_id}/views',
    'POST /v1/view-renders',
  ],
  'options_schema': <String, dynamic>{
    'properties': <String, dynamic>{
      'group_by': <String, dynamic>{
        'enum': <String>['holding', 'sector'],
      },
      'precision': <String, dynamic>{'type': 'integer'},
    },
  },
  'fields': <Map<String, dynamic>>[
    <String, dynamic>{
      'path': 'title',
      'type': 'string ≤120 chars',
      'presence': 'required',
      'binding': 'text',
      'state': null,
      'input': null,
    },
    <String, dynamic>{
      'path': 'group_by',
      'type': 'enum holding / sector',
      'presence': 'required',
      'binding': 'enum',
      'state': 'variant',
      'input': "input · one of 'holding', 'sector'",
    },
  ],
  'actions': <Map<String, dynamic>>[
    <String, dynamic>{
      'action': 'drill.attribution.v1',
      'label': 'Break this down',
      'arg': 'driver',
      'control': 'choice',
      'choices': <String>['AAPL'],
      'pattern': null,
    },
  ],
  'guidance': guidance,
  'prompt':
      '- holdings.allocation.v1 — Allocation of the portfolio, by holding.\n'
      "  options: group_by (one of 'holding', 'sector')",
  'example': holdingsAllocationExample,
};

/// A 200 answer carrying one catalog entry.
http.Response catalogResponse({String? etag, Object? body}) => http.Response(
  jsonEncode(body ?? <Object?>[catalogEntryJson()]),
  200,
  headers: <String, String>{'content-type': 'application/json', 'etag': ?etag},
);
