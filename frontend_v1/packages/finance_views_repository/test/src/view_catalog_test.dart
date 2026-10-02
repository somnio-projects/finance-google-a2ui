import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

import '../catalog_fixtures.dart';

void main() {
  group(ViewCatalog, () {
    test('keeps the entries in the order the backend listed them', () {
      final catalog = ViewCatalog.fromJson(<Object?>[
        catalogEntryJson(id: 'b.thing.v1'),
        catalogEntryJson(id: 'a.thing.v1'),
      ], etag: '"c1"');
      expect(catalog.entries.map((e) => e.id), <String>[
        'b.thing.v1',
        'a.thing.v1',
      ]);
      expect(catalog.etag, '"c1"');
      expect(catalog.props, hasLength(2));
    });

    test('finds an entry by id and answers null for an unserved view', () {
      final catalog = ViewCatalog.fromJson(<Object?>[catalogEntryJson()]);
      expect(catalog.entryFor('holdings.allocation.v1')?.component, isNotNull);
      expect(catalog.entryFor('nope.v9'), isNull);
    });

    test('rejects a body that is not an array', () {
      expect(
        () => ViewCatalog.fromJson(const <String, dynamic>{}),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            '<root>',
          ),
        ),
      );
    });

    test('names the index of a malformed entry', () {
      expect(
        () => ViewCatalog.fromJson(<Object?>[catalogEntryJson(), 'nope']),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            'views[1]',
          ),
        ),
      );
    });
  });
}
