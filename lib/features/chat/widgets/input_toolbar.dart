import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import '../model_selection_resolver.dart';
import 'model_mode.dart';
import 'permission_mode_selector.dart' as perm;

/// Visual chip height (dense). Hit target is expanded to
/// [AppTouchTarget.min] via outer padding so fat-finger misses drop.
const double _toolbarChipVisualHeight = 30;

/// Inline chip for model selection — subtle, tappable.
class ModelChip extends StatelessWidget {
  const ModelChip({
    required this.model,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final ChatModelMode model;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDefault = model == ChatModelMode.defaultModel;
    final displayLabel = isDefault ? 'Model' : model.label;
    final iconColor = isDefault ? cs.onSurfaceVariant : cs.primary;
    final chevronColor = isDefault
        ? cs.onSurfaceVariant.withValues(alpha: 0.65)
        : cs.primary.withValues(alpha: 0.65);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Model: ${model.label}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.min,
            minWidth: AppTouchTarget.min,
          ),
          // widthFactor/heightFactor keep Align intrinsic-sized so Wrap
          // places chips on one row; bare Align expands to full width.
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              height: _toolbarChipVisualHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                    model.isCodex
                        ? Icons.psychology_alt_outlined
                        : model.modelSlug == 'opus'
                        ? Icons.diamond_outlined
                        : model.modelSlug == 'sonnet'
                        ? Icons.auto_awesome_outlined
                        : model.modelSlug == 'fable'
                        ? Icons.auto_stories_outlined
                        : Icons.smart_toy_outlined,
                    size: 11,
                    color: enabled
                        ? iconColor
                        : iconColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    displayLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.xxs,
                      color: enabled
                          ? iconColor
                          : iconColor.withValues(alpha: 0.7),
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
          ),
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
    final displayLabel = isDefault ? 'Profile' : label;
    // Name alone is not routing — host shows which API the spawn hits.
    final host = profileBackendHost(profile);
    final semanticLabel = host == null
        ? 'Profile: $label'
        : 'Profile: $label · $host';
    final tooltip = host == null ? label : '$label · $host';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.min,
              minWidth: AppTouchTarget.min,
            ),
            // widthFactor/heightFactor keep Align intrinsic-sized so Wrap
            // places chips on one row; bare Align expands to full width.
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                height: _toolbarChipVisualHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 68),
                      child: Text(
                        displayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: AppFontSize.xxs,
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
                          ? cs.onSurfaceVariant.withValues(alpha: 0.65)
                          : cs.tertiary.withValues(alpha: 0.65),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline toggle chip for the 1M context window. When [oneMillion] is on,
/// the session spawns with the `[1m]` model suffix so Claude Code opens a
/// 1M-token window; when off, the model uses its default window.
class ContextWindowChip extends StatelessWidget {
  const ContextWindowChip({
    required this.oneMillion,
    required this.onTap,
    super.key,
  });

  final bool oneMillion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = oneMillion ? cs.secondary : cs.onSurfaceVariant;
    final label = oneMillion ? '1M context' : 'Default context';

    return Semantics(
      button: true,
      toggled: oneMillion,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.min,
              minWidth: AppTouchTarget.min,
            ),
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                height: _toolbarChipVisualHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: oneMillion
                      ? cs.secondary.withValues(alpha: 0.12)
                      : cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.aspect_ratio_rounded,
                      size: 11,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '1M',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xxs,
                        color: color,
                        fontWeight: oneMillion
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Context-size indicator showing token usage.
class ContextSizeIndicator extends StatelessWidget {
  const ContextSizeIndicator({
    required this.contextSize,
    this.maxContext = defaultMaxContext,
    super.key,
  });

  final int contextSize;

  /// The window the [contextSize] is measured against. Reflects the
  /// selected context window (1M vs. the model's default).
  final int maxContext;

  /// Conservative default budget for the standard (non-1M) window.
  static const int defaultMaxContext = 190000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pctUsed = (contextSize / maxContext * 100).clamp(0.0, 100.0);
    final pctRemaining = (100 - pctUsed).round();

    final Color indicatorColor;
    if (pctRemaining <= 5) {
      indicatorColor = cs.error;
    } else if (pctRemaining <= 15) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = cs.onSurfaceVariant.withValues(alpha: 0.65);
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
            borderRadius: BorderRadius.circular(AppRadius.hairline),
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
    this.availableModels = ChatModelMode.values,
    this.selectedProfile,
    this.contextSize,
    this.sessionFlavor,
    this.oneMillionContext = false,
    this.onContextWindowChanged,
  });

  final perm.PermissionMode? permissionMode;
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;
  final ChatModelMode? modelMode;
  final List<ChatModelMode> availableModels;
  final VoidCallback onShowModelPicker;
  final AIBackendProfile? selectedProfile;
  final VoidCallback onShowProfilePicker;
  final int? contextSize;

  /// Session agent flavor (`claude`, `codex`, …). Codex sessions get
  /// Codex permission modes instead of Claude/Gemini ones.
  final String? sessionFlavor;

  /// Whether the 1M context window is selected for the current model.
  final bool oneMillionContext;

  /// Called with the desired 1M state when the user toggles the chip.
  /// Null hides the chip.
  final ValueChanged<bool>? onContextWindowChanged;

  @override
  Widget build(BuildContext context) {
    final model = modelMode ?? ChatModelMode.defaultModel;

    // Wrap (not SingleChildScrollView) so chips never scroll horizontally —
    // when the row is wider than the available space, chips flow to the next
    // line instead. This keeps every chip tappable without a surprise gesture.
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onPermissionModeChanged != null)
          perm.PermissionModeSelector(
            selectedMode: permissionMode,
            onModeChanged: onPermissionModeChanged,
            availableModes: sessionFlavor == 'codex'
                ? perm.PermissionModeExtension.codexModes
                : perm.PermissionModeExtension.claudeGeminiModes,
          ),
        ModelChip(
          model: model,
          enabled: availableModels.length > 1,
          onTap: onShowModelPicker,
        ),
        ProfileChip(profile: selectedProfile, onTap: onShowProfilePicker),
        if (onContextWindowChanged != null)
          ContextWindowChip(
            oneMillion: oneMillionContext,
            onTap: () => onContextWindowChanged!(!oneMillionContext),
          ),
        if (contextSize != null && contextSize! > 0)
          ContextSizeIndicator(
            contextSize: contextSize!,
            maxContext: oneMillionContext
                ? ChatModelMode.oneMillionContextWindowTokens
                : ContextSizeIndicator.defaultMaxContext,
          ),
      ],
    );
  }
}
