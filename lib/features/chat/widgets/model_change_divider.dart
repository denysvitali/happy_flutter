import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../model_display_name.dart';

/// A horizontal divider marking the point where the agent started
/// answering with a different model — a `/model` switch, a fallback, or
/// the CLI silently downgrading. Inserted by `buildChatListItems`.
///
/// Styled after [ClearedDivider] so inline transcript notices read as one
/// family, with a slightly stronger label: a model change alters the
/// answers below it, so it should not be as easy to skim past.
class ModelChangeDivider extends StatelessWidget {
  const ModelChangeDivider({
    required this.fromModel,
    required this.toModel,
    super.key,
  });

  final String fromModel;
  final String toModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lineColor = cs.onSurfaceVariant.withValues(
      alpha: AppOpacity.subtle,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(height: AppBorder.thin, color: lineColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: AppFontSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    context.l10n.chatModelChanged(
                      modelDisplayName(fromModel),
                      modelDisplayName(toModel),
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: AppFontSize.xxs,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(height: AppBorder.thin, color: lineColor),
          ),
        ],
      ),
    );
  }
}
