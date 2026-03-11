import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import 'chat_input_buttons.dart';
import 'claude_model.dart';
import 'permission_mode_selector.dart' as perm;

/// Inline chip for model selection — subtle, tappable.
class ModelChip extends StatelessWidget {
  const ModelChip({
    required this.model,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final ClaudeModel model;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDefault = model == ClaudeModel.defaultModel;
    final iconColor = isDefault ? cs.onSurfaceVariant : cs.primary;
    final chevronColor = isDefault
        ? cs.onSurfaceVariant.withValues(alpha: 0.5)
        : cs.primary.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDefault
              ? cs.onSurface.withValues(alpha: 0.05)
              : cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              model == ClaudeModel.opus
                  ? Icons.diamond_outlined
                  : model == ClaudeModel.sonnet
                  ? Icons.auto_awesome_outlined
                  : Icons.smart_toy_outlined,
              size: 11,
              color: enabled ? iconColor : iconColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 3),
            Text(
              model.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppFontSize.xs,
                color: enabled ? iconColor : iconColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 1),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 12,
                color: chevronColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline chip for profile selection — shown next to
/// model chip.
class ProfileChip extends StatelessWidget {
  const ProfileChip({required this.profile, required this.onTap, super.key});

  final AIBackendProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDefault = profile == null;
    final label =
        profile?.name ?? AppLocalizations.of(context).chatInputProfileDefault;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDefault
              ? cs.onSurface.withValues(alpha: 0.05)
              : cs.tertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: 11,
              color: isDefault ? cs.onSurfaceVariant : cs.tertiary,
            ),
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppFontSize.xs,
                  color: isDefault ? cs.onSurfaceVariant : cs.tertiary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 1),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 12,
              color: isDefault
                  ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                  : cs.tertiary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Context-size indicator showing token usage.
class ContextSizeIndicator extends StatelessWidget {
  const ContextSizeIndicator({required this.contextSize, super.key});

  final int contextSize;

  static const int _maxContext = 190000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pctUsed = (contextSize / _maxContext * 100).clamp(0.0, 100.0);
    final pctRemaining = (100 - pctUsed).round();

    final Color indicatorColor;
    if (pctRemaining <= 5) {
      indicatorColor = cs.error;
    } else if (pctRemaining <= 15) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = cs.onSurfaceVariant.withValues(alpha: 0.4);
    }

    final String label;
    if (contextSize >= 1000) {
      final kVal = (contextSize / 1000).toStringAsFixed(0);
      label = '${kVal}k';
    } else {
      label = '$contextSize';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 2,
          child: ClipRRect(
            clipBehavior: Clip.hardEdge,
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: pctUsed / 100,
              backgroundColor: cs.onSurface.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: indicatorColor,
            fontSize: AppFontSize.xxs,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Toolbar row — clean horizontal strip with inline chips.
class InputToolbar extends StatelessWidget {
  const InputToolbar({
    required this.onShowModelPicker,
    required this.onShowProfilePicker,
    super.key,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.modelMode,
    this.availableModels = ClaudeModel.values,
    this.selectedProfile,
    this.contextSize,
    this.showAbort = false,
    this.isAborting = false,
    this.onAbort,
  });

  final perm.PermissionMode? permissionMode;
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;
  final ClaudeModel? modelMode;
  final List<ClaudeModel> availableModels;
  final VoidCallback onShowModelPicker;
  final AIBackendProfile? selectedProfile;
  final VoidCallback onShowProfilePicker;
  final int? contextSize;
  final bool showAbort;
  final bool isAborting;
  final VoidCallback? onAbort;

  @override
  Widget build(BuildContext context) {
    final model = modelMode ?? ClaudeModel.defaultModel;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          if (onPermissionModeChanged != null) ...[
            perm.PermissionModeSelector(
              selectedMode: permissionMode,
              onModeChanged: onPermissionModeChanged,
              availableModes: perm.PermissionModeExtension.claudeGeminiModes,
            ),
            const SizedBox(width: 6),
          ],
          ModelChip(
            model: model,
            enabled: availableModels.length > 1,
            onTap: onShowModelPicker,
          ),
          const SizedBox(width: 6),
          ProfileChip(profile: selectedProfile, onTap: onShowProfilePicker),
          const SizedBox(width: AppSpacing.sm),
          if (showAbort) ...[
            AbortButton(isAborting: isAborting, onTap: onAbort),
            if (contextSize != null && contextSize! > 0)
              const SizedBox(width: 6),
          ],
          if (contextSize != null && contextSize! > 0)
            ContextSizeIndicator(contextSize: contextSize!),
        ],
      ),
    );
  }
}
