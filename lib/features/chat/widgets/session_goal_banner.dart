import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_inline_row.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_tokens.dart';

/// Sticky chat banner showing the current Codex goal for this session.
class SessionGoalBanner extends ConsumerWidget {
  const SessionGoalBanner({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(
      sessionsNotifierProvider.select(
        (sessions) => sessions[sessionId]?.agentState?.goal,
      ),
    );

    if (goal == null || !goal.isVisible) return const SizedBox.shrink();

    return _GoalBannerBody(key: ValueKey(sessionId), goal: goal);
  }
}

class _GoalBannerBody extends StatefulWidget {
  const _GoalBannerBody({required this.goal, super.key});

  final CodexGoal goal;

  @override
  State<_GoalBannerBody> createState() => _GoalBannerBodyState();
}

class _GoalBannerBodyState extends State<_GoalBannerBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final status = goal.status.trim().isEmpty ? 'active' : goal.status.trim();
    final action = _expanded
        ? l10n.toolOutputShowLess
        : l10n.toolOutputShowMore;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInlineRow(
          leading: Icon(Icons.flag_rounded, color: cs.primary),
          onTap: () => setState(() => _expanded = !_expanded),
          semanticLabel: '${l10n.goalLoopsGoalLabel}, $status',
          semanticHint: action,
          expanded: _expanded,
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  Text(
                    l10n.goalLoopsGoalLabel,
                    style: AppInlineText.title(context),
                  ),
                  Text(status, style: AppInlineText.secondary(context)),
                ],
              ),
              if (!_expanded)
                Text(
                  goal.objective,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppInlineText.secondary(context),
                ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.25,
              ),
              child: SingleChildScrollView(
                key: const ValueKey('goal-objective-scroll'),
                child: SelectableText(
                  goal.objective,
                  style: AppInlineText.body(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
