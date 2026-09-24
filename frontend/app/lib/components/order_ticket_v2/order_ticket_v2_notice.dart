import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_chrome.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The design's validation banner: an `!` disc and one sentence.
///
/// Measured: radius **10**, padding **10 × 12**, an 18 px disc, 10 px between.
/// The sentence is the backend's — `constraints.message` for a blocked draft,
/// the RFC 9457 `detail` for a refused edit — rendered verbatim (N-9). Never
/// a stack trace, never a library message (ADR-L §4).
class OrderTicketV2Notice extends StatelessWidget {
  /// Creates the notice.
  const OrderTicketV2Notice({required this.message, super.key});

  /// The sentence, rendered verbatim.
  final String message;

  @override
  Widget build(BuildContext context) {
    final chrome = OrderTicketV2Chrome.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chrome.noticeSurface,
          border: Border.all(color: chrome.noticeBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: chrome.noticeIcon,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 18,
                  child: Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: chrome.noticeIconText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: OrderTicketV2Text.notice(chrome.noticeText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
