import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  group(RenderedViews, () {
    test('decodes the envelope and every view in it', () {
      final envelope = RenderedViews.fromJson(
        renderedViewsEnvelope(),
        etag: '"de120f2"',
      );
      expect(envelope.asOf, equals('2026-09-20T00:00:00Z'));
      expect(envelope.portfolioId, equals('current'));
      expect(envelope.etag, equals('"de120f2"'));
      expect(envelope.views.keys, equals(<String>['holdings.allocation.v1']));
      expect(
        envelope.views['holdings.allocation.v1']!.text('title'),
        equals('Allocation by holding'),
      );
    });

    test('keeps as_of as the string the backend sent', () {
      // N-13: the portfolio's time is the backend's, never a device clock,
      // and it is never re-formatted here.
      final envelope = RenderedViews.fromJson(renderedViewsEnvelope());
      expect(envelope.asOf, isA<String>());
    });

    test('supports value equality', () {
      expect(
        RenderedViews.fromJson(renderedViewsEnvelope()),
        equals(RenderedViews.fromJson(renderedViewsEnvelope())),
      );
    });

    test('props are correct', () {
      final envelope = RenderedViews.fromJson(
        renderedViewsEnvelope(),
        etag: '"e"',
      );
      expect(
        envelope.props,
        equals(<Object?>[
          envelope.asOf,
          envelope.portfolioId,
          envelope.views,
          '"e"',
        ]),
      );
    });

    group('withEtag', () {
      test('re-labels the envelope and changes nothing else', () {
        final envelope = RenderedViews.fromJson(renderedViewsEnvelope());
        final relabelled = envelope.withEtag('"new"');
        expect(relabelled.etag, equals('"new"'));
        expect(relabelled.asOf, equals(envelope.asOf));
        expect(relabelled.views, equals(envelope.views));
      });
    });

    group('fromJson', () {
      test('throws when the body is not an object', () {
        expect(
          () => RenderedViews.fromJson('nope'),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              equals('<root>'),
            ),
          ),
        );
      });

      test('throws naming the envelope field that is wrong', () {
        for (final field in <String>['as_of', 'portfolio_id', 'views']) {
          expect(
            () =>
                RenderedViews.fromJson(renderedViewsEnvelope()..remove(field)),
            throwsA(
              isA<PayloadContractException>().having(
                (e) => e.failure.path,
                'path',
                equals(field),
              ),
            ),
            reason: 'removing $field must be reported as $field',
          );
        }
      });
    });
  });
}
