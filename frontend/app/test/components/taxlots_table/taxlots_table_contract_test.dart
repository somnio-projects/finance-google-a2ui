import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import 'taxlots_table_harness.dart';

/// What the component does when the payload breaks its own contract.
///
/// Every one of these raises and **names the path**, which is N-3: the
/// alternative is a plausible-looking table with a field quietly missing,
/// and `ComponentHost` renders the violation precisely so that cannot
/// happen unnoticed.
void main() {
  group('$TaxLotsTableComponent contract violations', () {
    const component = TaxLotsTableComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('TaxLotTable');
    });

    Matcher raisesPath(String path) => throwsA(
      isA<PayloadContractException>().having(
        (error) => error.failure.path,
        'path',
        path,
      ),
    );

    void expectRaises(Map<String, dynamic> payload, String path) {
      expect(
        () => component.read(ViewPayload.fromJson(payload)),
        raisesPath(path),
      );
    }

    test('raises a missing realised total rather than adding one up', () {
      final broken = Map<String, dynamic>.from(example)..remove('realized');
      expectRaises(broken, 'realized.label');
    });

    test('raises a missing subtitle', () {
      final broken = Map<String, dynamic>.from(example)..remove('subtitle');
      expectRaises(broken, 'subtitle');
    });

    test('raises a lot term the contract does not declare', () {
      expectRaises(withLotField(example, 'term', 'medium'), 'lots[0].term');
    });

    test('raises a by_term term the contract does not declare', () {
      expectRaises(withTermField(example, 'term', '?'), 'by_term[0].term');
    });

    test('raises a fully_sold that is not a boolean', () {
      // `flag` is as strict as `text`: a contract that publishes a boolean
      // and sends a word is a contract violation, not a truthy string.
      expectRaises(withLotField(example, 'fully_sold', 'yes'), 'fully_sold');
    });

    test('raises a trend the contract does not declare', () {
      expectRaises(withLotField(example, 'trend', 'sideways'), 'lots[0].trend');
    });

    test('raises a lot whose display string is missing', () {
      expectRaises(
        withLotField(example, 'gain_loss', null),
        'gain_loss.display',
      );
    });

    test('raises a term with no by_term half to label it', () {
      // Both halves relabelled short, so the long-term lot has no label to
      // read. The join is the only place a label could come from, and
      // inventing "Long-term" here would ignore the `locale` option.
      final halves = (example['by_term']! as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((half) => <String, dynamic>{...half, 'term': 'short'})
          .toList();
      expectRaises(<String, dynamic>{
        ...example,
        'by_term': halves,
      }, 'by_term[].label');
    });
  });
}
