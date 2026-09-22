import 'package:finance_app/features/catalog/design_preview_states.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';

void main() {
  group('preview states', () {
    late CatalogSnapshot snapshot;

    setUp(() {
      snapshot = CatalogSnapshot.load();
    });

    test('every designed page names a view the backend serves', () {
      final served = <String>{
        for (final view in snapshot.views) view['view'] as String,
      };
      expect(designPreviewStates.keys, everyElement(isIn(served)));
      expect(designPreviewStates, hasLength(6));
    });

    test('every option a state sends is one the view declares (N-7)', () {
      // Pinned against the generated contract rather than against this
      // table: the table is the client's claim, the snapshot is the
      // backend's, and a renamed option turns this red before a 422 does.
      for (final entry in designPreviewStates.entries) {
        final view = snapshot.views.firstWhere((v) => v['view'] == entry.key);
        final schema = view['options_schema'] as Map<String, dynamic>;
        final declared = (schema['properties'] as Map<String, dynamic>).keys;
        for (final state in entry.value) {
          expect(
            state.options.keys,
            everyElement(isIn(declared)),
            reason: '${entry.key}: "${state.label}" sends an undeclared option',
          );
        }
      }
    });

    test('an absent or loading state carries the sentence that says why', () {
      for (final states in designPreviewStates.values) {
        for (final state in states) {
          if (state.kind == PreviewKind.absent ||
              state.kind == PreviewKind.loading) {
            expect(state.note, isNotEmpty, reason: state.label);
            expect(state.options, isEmpty, reason: state.label);
          }
        }
      }
    });

    test('the example comes first, for every view', () {
      expect(
        previewStatesFor('holdings.allocation.v1').first,
        PreviewState.example,
      );
      expect(previewStatesFor('holdings.allocation.v1'), hasLength(4));
      expect(previewStatesFor('nope.thing.v9'), <PreviewState>[
        PreviewState.example,
      ]);
    });

    test('a state is a value', () {
      expect(PreviewState.loading.props, hasLength(4));
      expect(PreviewState.loading, PreviewState.loading);
      expect(PreviewState.loading, isNot(PreviewState.example));
    });
  });
}
