import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';
import '../model_display_name.dart';

/// A horizontal divider marking the point where the agent started
/// answering with a different model — a `/model` switch, a fallback, or
/// the CLI silently downgrading. Inserted by `buildChatListItems`.
///
/// Part of the inline-transcript divider family (see
/// [ClearedDivider]): centered label between two static hairline rules
/// that fade out toward the edges. The label carries slightly more
/// weight than a cleared notice — a model change alters every answer
/// below it — and the swap glyph picks up the accent so the event is
/// findable when skimming a long transcript.
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
    final glass = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(child: _buildRule(glass)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: AppFontSize.sm,
                  color: cs.primary,
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
                      fontWeight: FontWeight.w600,
                      fontSize: AppFontSize.xxs,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildRule(glass)),
        ],
      ),
    );
  }

  /// Static hairline rule fading transparent → glass → transparent.
  Widget _buildRule(AppColorScheme glass) {
    return Container(
      height: AppBorder.hairline,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            glass.glassBorder,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
