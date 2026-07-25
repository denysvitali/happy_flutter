import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';
import '../tool_section_view.dart';
import '../tool_view_helpers.dart';

/// Pretty view for the Codex MCP session tools (`mcp__codex__codex` and
/// `mcp__codex__codex-reply`).
///
/// The generic MCP fallback only shows the response text (when present) and
/// never surfaces the input. Codex prompts are the interesting payload — they
/// carry the full task description plus the session configuration — so this
/// view renders the prompt in full alongside compact metadata chips for the
/// model, sandbox mode, approval policy, and working directory.
class CodexMcpView extends StatelessWidget {
  /// Creates a [CodexMcpView].
  const CodexMcpView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input, result, and state.
  final Map<String, dynamic> tool;

  /// Optional metadata associated with this tool invocation.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? const <String, dynamic>{};
    final prompt = input['prompt'] as String?;
    final model = input['model'] as String?;
    final sandbox = input['sandbox'] as String?;
    final approvalPolicy = input['approval-policy'] as String?;
    final cwd = input['cwd'] as String?;
    final state = tool['state'] as String? ?? '';
    final response = mcpToolTextResult(tool['result']);

    final chips = <Widget>[
      if (model != null && model.isNotEmpty)
        _MetaChip(label: 'model', value: model),
      if (sandbox != null && sandbox.isNotEmpty)
        _MetaChip(label: 'sandbox', value: sandbox),
      if (approvalPolicy != null && approvalPolicy.isNotEmpty)
        _MetaChip(label: 'approval', value: approvalPolicy),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (cwd != null && cwd.isNotEmpty) ...[
          _CwdRow(cwd: cwd),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (prompt != null && prompt.isNotEmpty) ...[
          ToolSectionView(
            title: 'Prompt',
            trailing: ToolViewCopyButton(text: prompt),
            child: _ProseBox(text: prompt),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state == 'running') ...[
          const _WorkingRow(),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (response != null && response.isNotEmpty)
          ToolSectionView(
            title: 'Response',
            trailing: ToolViewCopyButton(text: response),
            child: _ProseBox(text: response),
          ),
      ],
    );
  }
}

/// Small monospace chip showing one session-config key/value pair.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: AppBorder.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppFontSize.xxs,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Courier New', 'Courier'],
              fontSize: AppFontSize.xs,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Working-directory row with a folder icon, truncated to one line.
class _CwdRow extends StatelessWidget {
  const _CwdRow({required this.cwd});

  final String cwd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.folder_outlined,
          size: AppIconSize.sm,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            cwd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Courier New', 'Courier'],
              fontSize: AppFontSize.xs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bordered prose container used for the prompt and response sections.
class _ProseBox extends StatelessWidget {
  const _ProseBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: AppFontSize.sm,
          color: theme.colorScheme.onSurface,
          height: AppLineHeight.relaxed,
        ),
      ),
    );
  }
}

/// Inline spinner shown while the Codex session is still running.
class _WorkingRow extends StatelessWidget {
  const _WorkingRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Codex is working…',
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
