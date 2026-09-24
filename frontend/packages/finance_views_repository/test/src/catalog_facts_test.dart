import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

import '../catalog_fixtures.dart';

void main() {
  group(CatalogField, () {
    test(
      'binds every served cell and keeps null where the table has a dash',
      () {
        final rows =
            catalogEntryJson()['fields']! as List<Map<String, dynamic>>;
        final title = CatalogField.fromJson(rows[0], 'views[0].fields[0]');
        final groupBy = CatalogField.fromJson(rows[1], 'views[0].fields[1]');
        expect(title.path, 'title');
        expect(title.type, 'string ≤120 chars');
        expect(title.presence, 'required');
        expect(title.binding, 'text');
        expect(title.state, isNull);
        expect(title.input, isNull);
        expect(groupBy.state, 'variant');
        expect(groupBy.input, "input · one of 'holding', 'sector'");
        expect(title, isNot(equals(groupBy)));
      },
    );

    test('names the path of a missing cell', () {
      expect(
        () =>
            CatalogField.fromJson(const <String, dynamic>{'path': 'x'}, 'f[0]'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            'f[0].type',
          ),
        ),
      );
    });
  });

  group(CatalogGuidance, () {
    test('binds the pair verbatim', () {
      final pair = CatalogGuidance.fromJson(
        catalogEntryJson()['guidance']! as Map<String, dynamic>,
        'views[0].guidance',
      );
      expect(pair.useWhen, 'the user asks what is held now');
      expect(pair.avoidWhen, contains('attribution.waterfall.v1'));
      expect(pair.props, hasLength(2));
    });
  });

  group(CatalogAction, () {
    test('binds the declaration and ignores the bound it does not show', () {
      final rows = catalogEntryJson()['actions']! as List<Map<String, dynamic>>;
      final action = CatalogAction.fromJson(rows.single, 'views[0].actions[0]');
      expect(action.action, 'drill.attribution.v1');
      expect(action.label, 'Break this down');
      expect(action.arg, 'driver');
      expect(action.control, 'choice');
      expect(action.props, hasLength(4));
    });
  });

  group('catalog readers', () {
    const json = <String, dynamic>{
      'words': <Object?>['a', 1],
      'rows': <Object?>[1],
      'text': 3,
    };

    test('reject an array that is not all strings', () {
      expect(
        () => catalogStrings(json, 'words', 'e'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.message,
            'message',
            contains('an array of strings'),
          ),
        ),
      );
      expect(
        () => catalogStrings(json, 'text', 'e'),
        throwsA(isA<PayloadContractException>()),
      );
    });

    test('reject rows that are not objects, or not an array', () {
      expect(
        () => catalogRows(json, 'rows', 'e', (row, path) => path),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.message,
            'message',
            contains('an array of objects'),
          ),
        ),
      );
      expect(
        () => catalogRows(json, 'text', 'e', (row, path) => path),
        throwsA(isA<PayloadContractException>()),
      );
    });

    test('hand each row its own indexed path', () {
      final paths = catalogRows(
        <String, dynamic>{
          'rows': <Object?>[<String, dynamic>{}, <String, dynamic>{}],
        },
        'rows',
        'views[2]',
        (row, path) => path,
      );
      expect(paths, <String>['views[2].rows[0]', 'views[2].rows[1]']);
      expect(catalogOptionalString(json, 'text'), isNull);
    });
  });
}
