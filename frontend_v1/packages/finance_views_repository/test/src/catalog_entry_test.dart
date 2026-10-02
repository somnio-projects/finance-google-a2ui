import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

import '../catalog_fixtures.dart';

void main() {
  group(CatalogEntry, () {
    test('binds every served fact of one view', () {
      final entry = CatalogEntry.fromJson(catalogEntryJson());
      expect(entry.id, 'holdings.allocation.v1');
      expect(entry.summary, 'Allocation of the portfolio, by holding.');
      expect(entry.component, 'HoldingsSummary');
      expect(entry.endpoints, hasLength(2));
      expect(entry.optionNames, <String>['group_by', 'precision']);
      expect(entry.fields.map((f) => f.path), <String>['title', 'group_by']);
      expect(entry.actions.single.action, 'drill.attribution.v1');
      expect(entry.guidance?.useWhen, 'the user asks what is held now');
      expect(entry.prompt, startsWith('- holdings.allocation.v1 — '));
      expect(entry.example.view, 'holdings.allocation.v1');
      expect(entry.props, hasLength(10));
    });

    test('declares tells a caller which options it may send (N-7)', () {
      final entry = CatalogEntry.fromJson(catalogEntryJson());
      expect(entry.declares('group_by'), isTrue);
      expect(entry.declares('side'), isFalse);
    });

    test('carries no guidance where design wrote no page', () {
      final entry = CatalogEntry.fromJson(catalogEntryJson(guidance: null));
      expect(entry.guidance, isNull);
    });

    test('declares no options when the schema lists no properties', () {
      final json = catalogEntryJson()
        ..['options_schema'] = <String, dynamic>{'type': 'object'};
      expect(CatalogEntry.fromJson(json).optionNames, isEmpty);
    });

    test('rejects a schema that is not an object, naming the path', () {
      final json = catalogEntryJson()..['options_schema'] = 'nope';
      expect(
        () => CatalogEntry.fromJson(json, path: 'views[3]'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            'views[3].options_schema',
          ),
        ),
      );
    });

    test('rejects an entry that is not an object', () {
      expect(
        () => CatalogEntry.fromJson(const <Object?>[]),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            'views[]',
          ),
        ),
      );
    });

    test('rejects an entry whose example is not a payload', () {
      final json = catalogEntryJson()..['example'] = 'nope';
      expect(
        () => CatalogEntry.fromJson(json),
        throwsA(isA<PayloadContractException>()),
      );
    });
  });
}
