import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

void main() {
  group('pointerTokens', () {
    test('reads the whole model from "" and "/"', () {
      expect(pointerTokens(''), isEmpty);
      expect(pointerTokens('/'), isEmpty);
    });

    test('unescapes ~1 and ~0', () {
      expect(pointerTokens('/a~1b/c~0d'), <String>['a/b', 'c~d']);
    });

    test('refuses a pointer without a leading slash', () {
      expect(() => pointerTokens('root'), throwsFormatException);
    });
  });

  group('readPointer', () {
    const model = <String, Object?>{
      'root': <String, Object?>{
        'rows': <Object?>['a', 'b'],
      },
    };

    test('reads objects and list elements', () {
      expect(readPointer(model, '/root/rows/1'), 'b');
      expect(readPointer(model, '/'), model);
    });

    test('answers null for anything absent', () {
      expect(readPointer(model, '/root/rows/2'), isNull);
      expect(readPointer(model, '/root/rows/-'), isNull);
      expect(readPointer(model, '/root/rows/01'), isNull);
      expect(readPointer(model, '/root/rows/x'), isNull);
      expect(readPointer(model, '/root/rows/'), isNull);
      expect(readPointer(model, '/root/rows/0/deeper'), isNull);
      expect(readPointer(model, '/missing'), isNull);
    });
  });

  group('writePointer', () {
    test('creates missing objects and leaves the input untouched', () {
      const input = <String, Object?>{};
      final output = writePointer(input, '/a/b', 1);
      expect(output, <String, Object?>{
        'a': <String, Object?>{'b': 1},
      });
      expect(input, isEmpty);
    });

    test('replaces, deletes and replaces the root', () {
      const input = <String, Object?>{'a': 1, 'b': 2};
      expect(writePointer(input, '/a', 3), <String, Object?>{'a': 3, 'b': 2});
      expect(writePointer(input, '/a', null), <String, Object?>{'b': 2});
      expect(writePointer(input, '/', <String, Object?>{'c': 1}), {'c': 1});
      expect(writePointer(input, '/', null), isEmpty);
    });

    test('appends, replaces and removes list elements', () {
      const input = <String, Object?>{
        'l': <Object?>[1, 2],
      };
      expect(writePointer(input, '/l/-', 3)['l'], <Object?>[1, 2, 3]);
      expect(writePointer(input, '/l/2', 3)['l'], <Object?>[1, 2, 3]);
      expect(writePointer(input, '/l/0', 9)['l'], <Object?>[9, 2]);
      expect(writePointer(input, '/l/0', null)['l'], <Object?>[2]);
      expect(writePointer(input, '/l/-', null)['l'], <Object?>[1, 2]);
      expect(
        writePointer(
          <String, Object?>{
            'l': <Object?>[<String, Object?>{}],
          },
          '/l/0/k',
          1,
        )['l'],
        <Object?>[
          <String, Object?>{'k': 1},
        ],
      );
    });

    test('refuses paths the model cannot hold', () {
      const input = <String, Object?>{
        's': 1,
        'l': <Object?>[1],
      };
      expect(() => writePointer(input, '/s/x', 1), throwsFormatException);
      expect(() => writePointer(input, '/l/5', 1), throwsFormatException);
      expect(() => writePointer(input, '/', 'x'), throwsFormatException);
      expect(
        () => writePointer(input, '/l/1234567890', 1),
        throwsFormatException,
      );
    });
  });
}
