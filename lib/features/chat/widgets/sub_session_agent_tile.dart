import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/wire/wire_parsers.dart';
import '../sub_session/sub_session_agents.dart';
import '../sub_session/sub_session_projection.dart';
import '../sub_session/sub_session_state_badge.dart';
import '../tools/tool_status_indicator.dart';
import '../tools/tool_view_helpers.dart' show parseToolState, toolStateTone;

/// Agents-sheet row for one child Happy session thread.
///
/// Shows the latest turn's description, the child's title and live state,
/// and the number of turns. Tapping opens the child chat, not an
/// in-process agent conversation.
class SubSessionAgentTile extends StatelessWidget {
  const SubSessionAgentTile({required this.agent, super.key, this.onTap});

  /// Row built by [buildSubSessionAgentRows].
  final Map<String, dynamic> agent;

  /// Sheet callback; callers route with `AgentsListSheet.routeForAgent`.
  final void Function(Map<String, dynamic> agent, String navigationId)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final childId = subSessionAgentChildId(agent);
    final input = WireParsers.asMap(agent['input']);
    final description =
        _text(input?['description']) ??
        _text(agent[subSessionTitleField]) ??
        l10n.subSessionLabel;
    final title = _text(agent[subSessionTitleField]);
    final childState = SubSessionChildState.values.firstWhere(
      (state) => state.name == agent[subSessionChildStateField],
      orElse: () => SubSessionChildState.notLoaded,
    );
    final turns = agent[subSessionTurnCountField] as int? ?? 1;
    final toolState = parseToolState(agent['state'] as String?);
    final borderColor = AppToneColors.of(
      context,
      toolStateTone(toolState),
    ).outline;
    final canOpen = childId != null;

    return InkWell(
      onTap: canOpen
          ? () {
              final tap = onTap;
              if (tap != null) {
                tap(agent, agent['id'] as String? ?? childId);
              } else {
                Navigator.pop(context);
                context.push('/chat/$childId');
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxxs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: ToolStatusIndicator(state: toolState, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppBadge(
                        label: l10n.subSessionLabel,
                        leading: const Icon(Icons.account_tree_outlined),
                        color: cs.primary,
                      ),
                      SubSessionStateBadge(state: childState),
                      if (turns > 1)
                        AppBadge(label: l10n.subSessionTurnCount(turns)),
                      if (title != null && title != description)
                        Text(
                          title,
                          style: AppText.secondary(theme),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canOpen)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
