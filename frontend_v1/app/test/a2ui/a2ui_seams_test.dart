import 'dart:io';

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/action_clock.dart';
import 'package:finance_app/a2ui/finance_catalog.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/section/section_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionClock', () {
    test('answers now, in UTC, as ISO 8601', () {
      final stamp = const ActionClock().now();
      expect(stamp, endsWith('Z'));
      expect(DateTime.parse(stamp).isUtc, isTrue);
    });
  });

  group('readFinanceCatalog', () {
    test('reads the bundled catalog and its composition rules', () {
      final catalog = readFinanceCatalog(
        File(financeCatalogAsset).readAsStringSync(),
      );
      expect(catalog.catalogId, financeCatalogId);
      expect(catalog.components['RiskPayoffChart']!.allowedParents, <String>[
        'OrderTicket',
        'MultiLegOrderTicket',
      ]);
      expect(catalog.functions, contains(renderViewFunction));
    });

    test('an absent or unreadable document declares no component', () {
      for (final source in <String?>[null, '', '[]', '{"components":{}}']) {
        final catalog = readFinanceCatalog(source);
        expect(catalog.catalogId, financeCatalogId);
        expect(catalog.components, isEmpty);
      }
    });
  });

  group('ComponentRegistry layouts', () {
    test('registers a layout once, by its catalog name', () {
      final registry = ComponentRegistry()
        ..registerLayout(const SectionComponent());
      expect(registry.layout('Section'), isA<SectionComponent>());
      expect(registry.layout('TaxLotTable'), isNull);
      expect(
        () => registry.registerLayout(const SectionComponent()),
        throwsStateError,
      );
    });
  });
}
