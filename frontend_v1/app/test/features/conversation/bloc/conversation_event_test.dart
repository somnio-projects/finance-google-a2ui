import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ConversationMessageSent, () {
    test('is equal by the text it carries', () {
      // Asserted on `props` directly: both literals are `const`, so Dart
      // canonicalises them to one instance and `==` returns on its
      // `identical` short-circuit without ever reading `props`.
      expect(
        const ConversationMessageSent('what moved?').props,
        equals(<Object?>['what moved?']),
      );
      expect(
        const ConversationMessageSent('a'),
        isNot(equals(const ConversationMessageSent('b'))),
      );
    });
  });

  group(ConversationSurfaceEdited, () {
    test('is equal by surface, component, option and value', () {
      expect(
        const ConversationSurfaceEdited(
          surfaceId: 's',
          componentId: 'root',
          option: 'size',
          value: '3',
        ).props,
        equals(<Object?>['s', 'root', 'size', '3']),
      );
    });
  });

  group(ConversationRetried, () {
    test('carries nothing: what it repeats is read from the state', () {
      expect(const ConversationRetried().props, isEmpty);
    });
  });
}
