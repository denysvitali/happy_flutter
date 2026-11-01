import 'package:flutter/material.dart';
import 'app_badge.dart';

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
    final isSuccess = exitCode == 0;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xsm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(
            label: 'exit $exitCode',
            tone: isSuccess ? AppBadgeTone.success : AppBadgeTone.danger,
            leading: Icon(
              isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined,
            ),
            monospace: true,
          ),
        ],
      ),
    );
  }
}
