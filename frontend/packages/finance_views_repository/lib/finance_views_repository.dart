/// Repository layer — the seam between "an HTTP response" and "a view a
/// component can bind".
///
/// It composes the API client, keeps the `ETag` bookkeeping that makes a
/// revalidation cheap, and hands up `ViewPayload`s. It holds no Flutter, no
/// widget and no business rule: every figure it carries was formatted by the
/// backend and travels through untouched (ADR-K D-5).
library;

export 'src/payload_contract_exception.dart';
export 'src/rendered_views.dart';
export 'src/view_chunks.dart';
export 'src/view_payload.dart';
export 'src/views_batch.dart';
export 'src/views_repository.dart';
