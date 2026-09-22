import 'package:finance_app/features/conversation/bloc/conversation_entry.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

/// Turns a render intent into the entry the transcript shows for it.
///
/// The intent names a view and carries no payload, so the client fetches it —
/// through the same read path and the same options a `?view=` request uses.
/// The agent picked from the registry; it did not invent a shape. A missing
/// payload or a failed read becomes [SurfaceUnavailable], shown rather than
/// dropped: the turn succeeded and the answer is still worth reading.
Future<ConversationEntry> fetchSurfaceEntry(
  ViewsRepository views, {
  required String portfolioId,
  required AgentSurfaceReady intent,
}) async {
  final result = await views.fetchPortfolioViews(
    portfolioId: portfolioId,
    views: <String>[intent.view],
    options: intent.options,
  );
  return switch (result) {
    Ok<RenderedViews>(:final value) => switch (value.views[intent.view]) {
      null => SurfaceUnavailable(
        view: intent.view,
        message: 'The response carried no payload for this view.',
      ),
      final payload => AgentSurface(payload),
    },
    Err<RenderedViews>(:final failure) => SurfaceUnavailable(
      view: intent.view,
      message: failure.message,
    ),
  };
}
