import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

void main() {
  group('chunkViewIds', () {
    test('returns nothing for an empty list', () {
      expect(chunkViewIds(<String>[], 4), isEmpty);
    });

    test('returns one chunk when the list fits', () {
      expect(
        chunkViewIds(<String>['a', 'b'], 4),
        equals(<List<String>>[
          <String>['a', 'b'],
        ]),
      );
    });

    test('returns one chunk when the list is exactly the size', () {
      // The boundary that decides whether a four-component build makes one
      // request or two.
      expect(chunkViewIds(<String>['a', 'b', 'c', 'd'], 4).length, equals(1));
    });

    test('splits at the size and keeps the order', () {
      // Order is the contract: the ids come back to the caller in the order
      // they were asked for, which is what keeps N-10 untouched.
      expect(
        chunkViewIds(<String>['a', 'b', 'c', 'd', 'e'], 4),
        equals(<List<String>>[
          <String>['a', 'b', 'c', 'd'],
          <String>['e'],
        ]),
      );
    });

    test('loses nothing across several chunks', () {
      final ids = List<String>.generate(9, (i) => 'v$i');
      final flattened = <String>[
        for (final chunk in chunkViewIds(ids, 4)) ...chunk,
      ];
      expect(flattened, equals(ids));
    });

    test('refuses a non-positive size rather than looping forever', () {
      // A zero size would spin on `start += size`; a negative one would walk
      // backwards. Both are caller errors that no passing test would reveal,
      // so they are refused at the door.
      expect(() => chunkViewIds(<String>['a'], 0), throwsArgumentError);
      expect(() => chunkViewIds(<String>['a'], -1), throwsArgumentError);
    });
  });
}
