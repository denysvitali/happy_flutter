import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/components/tool_view_buttons.dart';
import '../tool_view_widgets.dart';

/// Boxed command card used by the shell-style tool views (Codex `bash`,
/// Gemini `execute`): terminal icon + label + optional cwd + copy button,
/// then the command itself, then an optional description banner.
///
/// Extracted because codex_bash_view and gemini_execute_view carried
/// byte-identical copies apart from the label and the banner.
class TerminalCommandBar extends StatelessWidget {
  const TerminalCommandBar({
    required this.command,
    this.cwd,
    this.description,
    this.label = 'bash',
    super.key,
  });

  /// The shell command, rendered selectable after a green `$` prompt.
  final String command;

  /// Optional working directory shown next to [label] in the title bar.
  final String? cwd;

  /// Optional italic banner appended under the command.
  final String? description;

  /// Title-bar label — 'bash' for Claude/Codex, 'execute' for Gemini.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: toolCardDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Container(
            padding: toolCardHeaderPadding,
            decoration: toolCardHeaderDecoration(cs),
            child: Row(
              children: [
                Icon(Icons.terminal,
                    size: AppIconSize.sm, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xsm),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                if (cwd != null && cwd!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '\u00b7',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      cwd!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.xs,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                ToolViewCopyButton(text: command, iconSize: 14),
              ],
            ),
          ),
          // Command line
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r'$',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SelectableText(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.md,
                      color: cs.onSurface,
                      height: AppLineHeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Optional description banner
          if (description != null && description!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xsm + 1,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.sm),
                  bottomRight: Radius.circular(AppRadius.sm),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: AppIconSize.xs, color: cs.primary),
                  const SizedBox(width: AppSpacing.xsm),
                  Expanded(
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
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
