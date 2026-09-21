import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Avatar, greeting, name and the simulation badge (spec 0026 §2).
///
/// Binds `greeting`, `account.initial`, `account.name` and `badge`. The
/// persona is seed data the backend serves (OD-1); nothing here knows whose
/// portfolio it is except by reading it.
class HomeHeader extends StatelessWidget {
  /// Creates the header.
  const HomeHeader({required this.payload, super.key});

  /// `portfolio.summary.v1`.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.header,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                payload.text('account.initial'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    payload.text('greeting'),
                    style: TextStyle(fontSize: 12, color: tokens.muted),
                  ),
                  Text(
                    payload.text('account.name'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                ],
              ),
            ),
            _Badge(text: payload.text('badge')),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.badge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tokens.badgeDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: tokens.badgeText,
            ),
          ),
        ],
      ),
    );
  }
}
