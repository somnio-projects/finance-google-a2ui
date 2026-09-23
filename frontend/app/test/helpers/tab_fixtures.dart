/// Envelopes for the Holdings and Activity tabs, read from the generated
/// catalog so a test binds what the backend really publishes.
library;

import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_snapshot.dart';

/// One envelope with [view] → the catalog's example for [component].
RenderedViews exampleEnvelope(String view, String component) =>
    RenderedViews.fromJson(<String, dynamic>{
      'as_of': '2026-01-15T12:00:00Z',
      'portfolio_id': 'current',
      'views': <String, dynamic>{
        view: CatalogSnapshot.load().exampleFor(component),
      },
    });

/// Stubs [repository] to answer [view] with [component]'s example.
///
/// [onCall] receives the options of each request as it is made. The debounce
/// tests need it: they used to wait a fixed twenty milliseconds and then
/// assert the call had happened, which is a race a loaded runner wins — and
/// did, on 2026-09-22. Watching the calls arrive lets a test wait for the one
/// it is about instead of for a clock.
void stubView(
  ViewsRepository repository,
  String view,
  String component, {
  void Function(Map<String, String> options)? onCall,
}) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: <String>[view],
      options: any(named: 'options'),
    ),
  ).thenAnswer((invocation) async {
    onCall?.call(
      Map<String, String>.from(
        invocation.namedArguments[#options] as Map<Object?, Object?>,
      ),
    );
    return Ok<RenderedViews>(exampleEnvelope(view, component));
  });
}

/// Stubs [repository] to fail [view] with [failure].
void stubFailure(ViewsRepository repository, String view, AppFailure failure) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: <String>[view],
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => Err<RenderedViews>(failure));
}

/// Wait until the request this step is about has actually been made.
///
/// These tests used to sleep `_debounce * 4` — twenty milliseconds of **real**
/// time — and then assert the call had happened. That is a race the runner
/// wins whenever it is busy: this file failed on CI on 2026-09-22 reporting
/// `All calls: …{kind: sell}`, the request without the query, because the
/// debounce had not fired yet. Raising the sleep only moves the threshold;
/// watching the calls arrive removes it. A step that expects the *second*
/// occurrence of an identical request says so with [times], which is why this
/// counts rather than using `untilCalled`.
Future<void> awaitRequest(
  List<Map<String, String>> calls,
  Map<String, String> options, {
  int times = 1,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  bool seen() =>
      calls.where((call) => mapEquals(call, options)).length >= times;
  while (!seen()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('no request with $options arrived $times time(s); saw $calls');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
