import 'package:flutter/material.dart';

import '../../features/chat/tools/tool_view_colors.dart';
import '../theme/app_tokens.dart';

/// Badge that displays a process exit code with success/error coloring
/// (0 = green success, non-zero = red error), using shared design tokens.
class ExitCodeBadge extends StatelessWidget {
  /// Creates a badge for the given [exitCode].
  const ExitCodeBadge({super.key, required this.exitCode});

  /// Process exit code. 0 renders as success, any other value as error.
  final int exitCode;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final isSuccess = exitCode == 0;
    final color = isSuccess ? c.green : c.red;
    final bgColor = isSuccess ? c.greenBadgeBg : c.redBadgeBg;
    final borderColor = isSuccess ? c.greenBadgeBorder : c.redBadgeBorder;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xsm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs - 1,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xxs2),
                Text(
                  'exit $exitCode',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.xs,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
