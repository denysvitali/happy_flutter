import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown_view.dart';

/// Collapsible prompt above the agent conversation feed.
class AgentConversationPrompt extends StatefulWidget {
  const AgentConversationPrompt({required this.prompt, super.key});

  final String prompt;

  @override
  State<AgentConversationPrompt> createState() =>
      _AgentConversationPromptState();
}

class _AgentConversationPromptState extends State<AgentConversationPrompt> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.smd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.smd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Prompt',
                      style: AppText.label(
                        theme,
                        theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: MarkdownView(
                        markdown: widget.prompt,
                        textColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Compact, always-visible debug card shown at the top of the agent
/// conversation feed. Mirrors the label/value rows in
/// `message_detail_screen` so the model a sub-agent was invoked with is
/// no longer invisible when something goes wrong (e.g. a gateway
/// "Model not exist." 400).
class AgentConversationDebugCard extends StatelessWidget {
  const AgentConversationDebugCard({
    required this.state,
    required this.messageId,
    this.subagentModel,
    this.parentModel,
    super.key,
  });

  final String state;
  final String messageId;
  final String? subagentModel;
  final String? parentModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Local copy so flow analysis promotes it past the null check
    // below (a public getter would not be promoted).
    final resolvedParentModel = parentModel;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.smd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                // TODO(i18n): localize these debug-card labels.
                Text('Debug', style: AppText.label(theme, cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _DebugRow(label: 'Model', value: subagentModel ?? '—', mono: true),
            if (subagentModel == null && resolvedParentModel != null)
              _DebugRow(
                label: 'Parent model',
                value: resolvedParentModel,
                mono: true,
              ),
            _DebugRow(label: 'State', value: state),
            _DebugRow(label: 'ID', value: messageId, mono: true),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppText.secondary(
                theme,
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppText.secondary(
                theme,
              ).copyWith(fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }
}
