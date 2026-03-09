import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import 'claude_model.dart';

// ---------------------------------------------------------------------------
// Model picker bottom sheet
// ---------------------------------------------------------------------------

Widget _buildModelTile(
  BuildContext ctx,
  ClaudeModel model,
  ClaudeModel current,
  ThemeData theme,
  ValueChanged<ClaudeModel> onChanged,
) {
  final cs = theme.colorScheme;
  final isSelected = model == current;

  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(ctx);
      onChanged(model);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              model == ClaudeModel.opus
                  ? Icons.diamond_outlined
                  : model == ClaudeModel.sonnet
                      ? Icons.auto_awesome_outlined
                      : Icons.smart_toy_outlined,
              size: 16,
              color: isSelected
                  ? cs.primary
                  : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              model.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color:
                    isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: cs.primary,
            ),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet for selecting a [ClaudeModel].
void showModelPickerSheet(
  BuildContext context,
  ClaudeModel current,
  ValueChanged<ClaudeModel> onChanged,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(2.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Model',
                style:
                    theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final model in ClaudeModel.values)
              _buildModelTile(
                ctx,
                model,
                current,
                theme,
                onChanged,
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Profile picker bottom sheet
// ---------------------------------------------------------------------------

Widget _buildProfileTile(
  BuildContext ctx,
  AIBackendProfile profile,
  AIBackendProfile? current,
  ThemeData theme,
  ValueChanged<AIBackendProfile?> onChanged,
) {
  final cs = theme.colorScheme;
  final isSelected = current?.id == profile.id;

  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(ctx);
      onChanged(profile);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.tertiary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: isSelected
                  ? cs.tertiary
                  : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? cs.tertiary
                        : cs.onSurface,
                  ),
                ),
                if (profile.description != null)
                  Text(
                    profile.description!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: cs.tertiary,
            ),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet for selecting an
/// [AIBackendProfile].
void showProfilePickerSheet(
  BuildContext context,
  AIBackendProfile? current,
  List<AIBackendProfile> profiles,
  ValueChanged<AIBackendProfile?> onChanged,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (ctx) {
      final sheetL10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(
                    bottom: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onSurface
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  sheetL10n.chatInputProfileTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Default (no profile) option
                      InkWell(
                        onTap: () {
                          HapticFeedback
                              .selectionClick();
                          Navigator.pop(ctx);
                          onChanged(null);
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: current == null
                                      ? cs.tertiary
                                          .withValues(
                                          alpha: 0.12,
                                        )
                                      : cs.onSurface
                                          .withValues(
                                          alpha: 0.05,
                                        ),
                                  shape:
                                      BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons
                                      .settings_outlined,
                                  size: 16,
                                  color: current == null
                                      ? cs.tertiary
                                      : cs
                                          .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(
                                width: AppSpacing.md,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      sheetL10n
                                          .chatInputProfileDefault,
                                      style: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        fontWeight: current ==
                                                null
                                            ? FontWeight
                                                .w600
                                            : FontWeight
                                                .w400,
                                        color: current ==
                                                null
                                            ? cs
                                                .tertiary
                                            : cs
                                                .onSurface,
                                      ),
                                    ),
                                    Text(
                                      sheetL10n
                                          .chatInputProfileDefaultSubtitle,
                                      style: theme
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        color: cs
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (current == null)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: cs.tertiary,
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (final profile in profiles)
                        _buildProfileTile(
                          ctx,
                          profile,
                          current,
                          theme,
                          onChanged,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
