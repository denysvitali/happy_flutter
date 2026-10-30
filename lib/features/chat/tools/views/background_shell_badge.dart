import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Status of a Bash command that Claude moved to a background shell.
///
/// [shell] is the tool call's `backgroundShell` map: `taskId`, `reason`
/// (`timeout`, `user`, `message`, `launched`), optional
/// `timedOutAfterMs` and `outputPath`, and the `status` the chat
/// pipeline pairs from the task's terminal notification (`running`
/// until one arrives).
class BackgroundShellBadge extends StatelessWidget {
  const BackgroundShellBadge({required this.shell, super.key});

  final Map<String, dynamic> shell;

  /// Headline for the badge, e.g. "Moved to background after 600s".
  static String describe(Map<String, dynamic> shell) {
    final timedOutAfterMs = shell['timedOutAfterMs'];
    final origin = switch (shell['reason']) {
      'timeout' when timedOutAfterMs is num =>
        'Moved to background after ${_seconds(timedOutAfterMs)}',
      'timeout' => 'Moved to background after timeout',
      'user' => 'Moved to background by you',
      'message' => 'Moved to background for a new message',
      'abort' => 'Moved to background when the turn stopped',
      _ => 'Background command',
    };
    final status = switch (shell['status']) {
      'completed' => 'finished',
      'failed' => 'failed',
      'stopped' => 'stopped',
      _ => 'still running',
    };
    return '$origin · $status';
  }

  static String _seconds(num ms) {
    final seconds = (ms / 1000).round();
    return '${seconds < 1 ? 1 : seconds}s';
  }

  /// Compact state for the collapsed tool header, where the Bash call
  /// itself reads as done the moment its command is backgrounded.
  static ({IconData icon, Color color, String label}) cue(
    Map<String, dynamic> shell,
  ) => switch (shell['status']) {
    'completed' => (
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      label: 'Background done',
    ),
    'failed' => (
      icon: Icons.cancel_outlined,
      color: AppColors.error,
      label: 'Background failed',
    ),
    'stopped' => (
      icon: Icons.stop_circle_outlined,
      color: AppColors.warning,
      label: 'Background stopped',
    ),
    _ => (
      icon: Icons.hourglass_top_rounded,
      color: AppColors.info,
      label: 'In background',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (:icon, :color, label: _) = cue(shell);
    final outputPath = shell['outputPath'] as String?;
    final taskId = shell['taskId'] as String?;

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs2),
          Flexible(
            child: Text(
              describe(shell),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (outputPath != null) ...[
            const SizedBox(width: AppSpacing.xxs2),
            Icon(Icons.copy_rounded, size: 12, color: color),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xsm),
      child: Semantics(
        label: [describe(shell), if (taskId != null) 'task $taskId'].join(', '),
        button: outputPath != null,
        excludeSemantics: true,
        child: Tooltip(
          message: outputPath ?? describe(shell),
          child: outputPath == null
              ? badge
              : InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  onTap: () => _copyOutputPath(context, outputPath),
                  child: badge,
                ),
        ),
      ),
    );
  }

  Future<void> _copyOutputPath(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied output path: $path'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
