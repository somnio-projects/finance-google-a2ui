import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// What part of a surface could not be drawn, and why — one line per refused
/// node, led by its protocol code (`UNALLOWED_PARENT`, `UNALLOWED_CHILD`,
/// `VALIDATION_FAILED`), so the reader sees the same code the renderer would
/// report to the agent (spec `frontend_v1/0001` AC-3).
class SurfaceNotice extends StatelessWidget {
  /// Lists [errors].
  const SurfaceNotice({required this.errors, super.key});

  /// One line, for a node refused for a reason with no protocol code.
  SurfaceNotice.single(String message, {Key? key})
    : this(
        errors: <RendererError>[
          RendererError(code: 'VALIDATION_FAILED', message: message),
        ],
        key: key,
      );

  /// What was refused.
  final List<RendererError> errors;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final error in errors)
            Text(
              '${error.code}: ${error.message}',
              style: TextStyle(fontSize: 12, color: tokens.muted),
            ),
        ],
      ),
    );
  }
}
