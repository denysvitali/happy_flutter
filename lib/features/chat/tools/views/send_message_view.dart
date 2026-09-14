import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/send_message_arguments.dart';

import '../tool_section_view.dart';
import '../tool_status_indicator.dart' show ToolState;
import '../tool_view_helpers.dart' show parseToolState;

/// Inline presentation for Claude Code's cross-agent `SendMessage` tool.
class SendMessageView extends StatelessWidget {
  const SendMessageView({required this.tool, super.key, this.boxed = false});

  final Map<String, dynamic> tool;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final args = SendMessageArguments.fromTool(tool);
    final result = sendMessageResultText(tool['result']);
    final state = parseToolState(tool['state'] as String?);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (args.recipient != null) _RecipientRow(recipient: args.recipient!),
        if (args.message != null) ...[
          if (args.recipient != null) const SizedBox(height: AppSpacing.sm),
          ToolSectionView(
            title: 'Message',
            trailing: ToolViewCopyButton(text: args.message!),
            child: _MessageBox(text: args.message!),
          ),
        ],
        if (state == ToolState.running) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sending…',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: AppFontSize.sm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (result != null && state != ToolState.running) ...[
          const SizedBox(height: AppSpacing.sm),
          ToolSectionView(
            title: state == ToolState.error ? 'Error' : 'Result',
            trailing: ToolViewCopyButton(text: result),
            child: _MessageBox(text: result),
          ),
        ],
      ],
    );
    return boxed ? ToolSectionView(child: body) : body;
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.recipient});

  final String recipient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: AppIconSize.md,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'To ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            recipient,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: AppFontSize.sm,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: AppLineHeight.relaxed,
        ),
      ),
    );
  }
}
