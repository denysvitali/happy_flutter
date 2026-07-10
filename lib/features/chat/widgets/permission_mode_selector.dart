import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Visual chip height (dense). Hit target expanded to [AppTouchTarget.min].
const double _selectorChipVisualHeight = 30;

/// Permission mode options for Claude/Gemini agents
enum PermissionMode {
  // Claude/Gemini modes
  defaultMode,
  acceptEdits,
  plan,
  bypassPermissions,
  // Codex modes
  readOnly,
  safeYolo,
  yolo,
}

/// Extension for PermissionMode with configuration
extension PermissionModeExtension on PermissionMode {
  /// Get the display name for this mode
  String get displayName {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'Default';
      case PermissionMode.acceptEdits:
        return 'Accept Edits';
      case PermissionMode.plan:
        return 'Plan';
      case PermissionMode.bypassPermissions:
        return 'Yolo';
      case PermissionMode.readOnly:
        return 'Read-only';
      case PermissionMode.safeYolo:
        return 'Safe YOLO';
      case PermissionMode.yolo:
        return 'YOLO';
    }
  }

  /// Get the description for this mode
  String get description {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'Ask for permissions';
      case PermissionMode.acceptEdits:
        return 'Auto-approve edits';
      case PermissionMode.plan:
        return 'Plan before executing';
      case PermissionMode.bypassPermissions:
        return 'Skip all permissions';
      case PermissionMode.readOnly:
        return 'Read-only mode';
      case PermissionMode.safeYolo:
        return 'Safe YOLO mode';
      case PermissionMode.yolo:
        return 'YOLO mode';
    }
  }

  /// Get the localized display name for this mode
  String localizedDisplayName(AppLocalizations l10n) {
    switch (this) {
      case PermissionMode.defaultMode:
        return l10n.permissionModeDefault;
      case PermissionMode.acceptEdits:
        return l10n.permissionModeAcceptEdits;
      case PermissionMode.plan:
        return l10n.permissionModePlan;
      case PermissionMode.bypassPermissions:
        return l10n.permissionModeBypass;
      case PermissionMode.readOnly:
        return l10n.permissionModeReadOnly;
      case PermissionMode.safeYolo:
        return l10n.permissionModeSafeYolo;
      case PermissionMode.yolo:
        return l10n.permissionModeYolo;
    }
  }

  /// Get the localized description for this mode
  String localizedDescription(AppLocalizations l10n) {
    switch (this) {
      case PermissionMode.defaultMode:
        return l10n.permissionModeDefaultDesc;
      case PermissionMode.acceptEdits:
        return l10n.permissionModeAcceptEditsDesc;
      case PermissionMode.plan:
        return l10n.permissionModePlanDesc;
      case PermissionMode.bypassPermissions:
        return l10n.permissionModeBypassDesc;
      case PermissionMode.readOnly:
        return l10n.permissionModeReadOnlyDesc;
      case PermissionMode.safeYolo:
        return l10n.permissionModeSafeYoloDesc;
      case PermissionMode.yolo:
        return l10n.permissionModeYoloDesc;
    }
  }

  /// Get the color for this mode
  Color get color {
    switch (this) {
      case PermissionMode.defaultMode:
        return AppColors.iosBlue;
      case PermissionMode.acceptEdits:
        return AppColors.permissionAutoEdit;
      case PermissionMode.plan:
        return AppColors.warning;
      case PermissionMode.bypassPermissions:
        return AppColors.permissionBypass;
      case PermissionMode.readOnly:
        return AppColors.permissionReadOnly;
      case PermissionMode.safeYolo:
        return AppColors.info;
      case PermissionMode.yolo:
        return AppColors.permissionUnrestricted;
    }
  }

  /// Get the icon for this mode
  IconData get icon {
    switch (this) {
      case PermissionMode.defaultMode:
        return Icons.shield_outlined;
      case PermissionMode.acceptEdits:
        return Icons.edit_outlined;
      case PermissionMode.plan:
        return Icons.list_alt_outlined;
      case PermissionMode.bypassPermissions:
        return Icons.flash_on_outlined;
      case PermissionMode.readOnly:
        return Icons.visibility_outlined;
      case PermissionMode.safeYolo:
        return Icons.security_outlined;
      case PermissionMode.yolo:
        return Icons.rocket_launch_outlined;
    }
  }

  /// Get the icon name string for this mode
  String get iconName {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'shield-checkmark';
      case PermissionMode.acceptEdits:
        return 'create';
      case PermissionMode.plan:
        return 'list';
      case PermissionMode.bypassPermissions:
        return 'flash';
      case PermissionMode.readOnly:
        return 'eye';
      case PermissionMode.safeYolo:
        return 'shield';
      case PermissionMode.yolo:
        return 'rocket';
    }
  }

  /// Check if this is a Claude/Gemini compatible mode
  bool get isClaudeGeminiMode {
    return this == PermissionMode.defaultMode ||
        this == PermissionMode.acceptEdits ||
        this == PermissionMode.plan ||
        this == PermissionMode.bypassPermissions;
  }

  /// Check if this is a Codex compatible mode
  bool get isCodexMode {
    return this == PermissionMode.defaultMode ||
        this == PermissionMode.readOnly ||
        this == PermissionMode.safeYolo ||
        this == PermissionMode.yolo;
  }

  /// Get modes for Claude/Gemini agents
  static List<PermissionMode> get claudeGeminiModes => [
    PermissionMode.defaultMode,
    PermissionMode.acceptEdits,
    PermissionMode.plan,
    PermissionMode.bypassPermissions,
  ];

  /// Get modes for Codex agents
  static List<PermissionMode> get codexModes => [
    PermissionMode.defaultMode,
    PermissionMode.readOnly,
    PermissionMode.safeYolo,
    PermissionMode.yolo,
  ];

  /// Get all available modes
  static List<PermissionMode> get allModes => PermissionMode.values;

  /// Parse mode from string
  static PermissionMode? fromString(String value) {
    final mapping = {
      'default': PermissionMode.defaultMode,
      'acceptEdits': PermissionMode.acceptEdits,
      'plan': PermissionMode.plan,
      'bypassPermissions': PermissionMode.bypassPermissions,
      'read-only': PermissionMode.readOnly,
      'readOnly': PermissionMode.readOnly,
      'safe-yolo': PermissionMode.safeYolo,
      'safeYolo': PermissionMode.safeYolo,
      'yolo': PermissionMode.yolo,
    };
    return mapping[value];
  }

  /// Convert to string for storage/API
  String toModeString() {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'default';
      case PermissionMode.acceptEdits:
        return 'acceptEdits';
      case PermissionMode.plan:
        return 'plan';
      case PermissionMode.bypassPermissions:
        return 'bypassPermissions';
      case PermissionMode.readOnly:
        return 'read-only';
      case PermissionMode.safeYolo:
        return 'safe-yolo';
      case PermissionMode.yolo:
        return 'yolo';
    }
  }
}

/// Permission mode selector — inline chip that opens a bottom sheet.
class PermissionModeSelector extends ConsumerWidget {
  const PermissionModeSelector({
    super.key,
    this.selectedMode,
    this.onModeChanged,
    this.enabled = true,
    this.width,
    this.availableModes,
  });

  final PermissionMode? selectedMode;
  final ValueChanged<PermissionMode>? onModeChanged;
  final bool enabled;
  final double? width;
  final List<PermissionMode>? availableModes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = selectedMode ?? PermissionMode.defaultMode;
    final cs = Theme.of(context).colorScheme;
    final isDefault = currentMode == PermissionMode.defaultMode;
    final l10n = AppLocalizations.of(context);
    final displayLabel = isDefault
        ? 'Permissions'
        : currentMode.localizedDisplayName(l10n);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Permission mode: ${currentMode.localizedDisplayName(l10n)}',
      child: InkWell(
        onTap: enabled ? () => _showModeSheet(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.min,
            minWidth: AppTouchTarget.min,
          ),
          // widthFactor/heightFactor keep Align intrinsic-sized so parent
          // Wrap places chips on one row; bare Align expands to full width.
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              width: width,
              height: _selectorChipVisualHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDefault
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : currentMode.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentMode.icon,
                    size: 11,
                    color: isDefault ? cs.onSurfaceVariant : currentMode.color,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    displayLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.xxs,
                      fontWeight: FontWeight.w500,
                      color: isDefault
                          ? cs.onSurfaceVariant
                          : currentMode.color,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 12,
                    color: isDefault
                        ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                        : currentMode.color.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showModeSheet(BuildContext context) {
    final modes = availableModes ?? PermissionMode.values;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    sheetL10n.permissionModeTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mode in modes)
                          _buildModeTile(ctx, mode, theme),
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

  Widget _buildModeTile(
    BuildContext ctx,
    PermissionMode mode,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final isSelected = (selectedMode ?? PermissionMode.defaultMode) == mode;
    final tileL10n = AppLocalizations.of(ctx);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(ctx);
        onModeChanged?.call(mode);
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
                    ? mode.color.withValues(alpha: 0.12)
                    : cs.onSurface.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                mode.icon,
                size: 16,
                color: isSelected ? mode.color : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.localizedDisplayName(tileL10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? mode.color : cs.onSurface,
                    ),
                  ),
                  Text(
                    mode.localizedDescription(tileL10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: mode.color),
          ],
        ),
      ),
    );
  }
}

/// Compact permission mode badge for display
class PermissionModeBadge extends StatelessWidget {
  const PermissionModeBadge({
    required this.mode,
    super.key,
    this.fontSize = 11,
    this.showIcon = false,
    this.padding,
  });
  final PermissionMode mode;
  final double fontSize;
  final bool showIcon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(mode.icon, size: fontSize + 2, color: mode.color),
            const SizedBox(width: 4),
          ],
          Text(
            mode.localizedDisplayName(AppLocalizations.of(context)),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mode.color,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large permission mode selector for settings overlay
class PermissionModeSettingsList extends StatelessWidget {
  const PermissionModeSettingsList({
    required this.onModeChanged,
    super.key,
    this.selectedMode,
    this.availableModes,
  });
  final PermissionMode? selectedMode;
  final ValueChanged<PermissionMode> onModeChanged;
  final List<PermissionMode>? availableModes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final modes = availableModes ?? PermissionMode.values;

    return RadioGroup<PermissionMode>(
      groupValue: selectedMode,
      onChanged: (value) {
        if (value != null) {
          onModeChanged(value);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.permissionModeTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...modes.map(
            (mode) => RadioListTile<PermissionMode>(
              value: mode,
              title: Row(
                children: [
                  Icon(mode.icon, size: 20, color: mode.color),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    mode.localizedDisplayName(l10n),
                    style: TextStyle(
                      color: selectedMode == mode ? mode.color : null,
                      fontWeight: selectedMode == mode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              subtitle: Text(mode.localizedDescription(l10n)),
              activeColor: mode.color,
            ),
          ),
        ],
      ),
    );
  }
}
