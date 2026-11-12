import 'package:finance_views_repository/finance_views_repository.dart';

/// The one sentence assistive technology reads for a timeline row: title,
/// caption, term badge, amount and the realised line or badge, each exactly
/// as the backend wrote it (GGU-157). Nothing is formatted or computed here;
/// the parts are only joined.
String activityEntryLabel(ViewPayload entry) {
  final parts = <String?>[
    entry.text('title'),
    entry.text('detail'),
    entry.optionalText('term.label'),
    entry.text('amount.display'),
    entry.optionalText('realized.text') ?? entry.text('badge'),
  ];
  return parts.whereType<String>().join(', ');
}
