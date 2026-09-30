import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../model_selection_resolver.dart';
import 'composer_selector_chip.dart';
import 'model_mode.dart';
import 'permission_mode_selector.dart' as perm;

/// Inline chip for model selection — subtle, tappable.
class ModelChip extends StatelessWidget {
  const ModelChip({
    required this.model,
    required this.onTap,
    this.enabled = true,
    this.resolvedLabel,
    super.key,
  });

  final ChatModelMode model;
  final VoidCallback onTap;
  final bool enabled;
  final String? resolvedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDefault = model == ChatModelMode.defaultModel;
    final value =
        resolvedLabel ??
        (isDefault ? l10n.chatInputProfileDefault : model.label);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${l10n.composerModelLabel}: ${resolvedLabel ?? model.label}',
      excludeSemantics: true,
      child: ComposerSelectorChip(onTap: enabled ? onTap : null, label: value),
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
    final l10n = AppLocalizations.of(context);
    final label = profile?.name ?? l10n.chatInputProfileDefault;
    // Name alone is not routing — host shows which API the spawn hits.
    final host = profileBackendHost(profile);
    final semanticLabel = host == null
        ? 'Profile: $label'
        : 'Profile: $label · $host';
    final tooltip = host == null ? label : '$label · $host';

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: ComposerSelectorChip(
          onTap: onTap,
          label: label,
          labelMaxWidth: 180,
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
            child: AppLinearProgressIndicator(
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
            fontSize: AppFontSize.sm,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Width of the trailing fade on the scrolling settings lane.
const double _laneFade = 16;

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
    this.canRefreshModels = false,
    this.selectedProfile,
    this.contextSize,
    this.sessionFlavor,
    this.maxContext,
    this.compact = false,
    this.resolvedModelLabel,
  });

  final perm.PermissionMode? permissionMode;
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;
  final ChatModelMode? modelMode;
  final List<ChatModelMode> availableModels;
  final bool canRefreshModels;
  final VoidCallback onShowModelPicker;
  final AIBackendProfile? selectedProfile;
  final VoidCallback onShowProfilePicker;
  final int? contextSize;

  /// Session agent flavor (`claude`, `codex`, …). Codex sessions get
  /// Codex permission modes instead of Claude/Gemini ones.
  final String? sessionFlavor;

  /// The context window [contextSize] is measured against, or null to use
  /// [ContextSizeIndicator.defaultMaxContext]. Derived from the selected
  /// profile's context-window setting.
  final int? maxContext;
  final bool compact;
  final String? resolvedModelLabel;

  @override
  Widget build(BuildContext context) {
    final model = modelMode ?? ChatModelMode.defaultModel;

    // Long provider and model names must not split composer controls across
    // two rows. Keep one dense lane and let overflow scroll instead.
    // Long provider and model names must not split composer controls across
    // two rows. Keep one dense lane and let overflow scroll instead.
    final lane = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      // Room for the fade so chips that fit are never dimmed.
      padding: const EdgeInsetsDirectional.only(end: _laneFade),
      child: Row(
        children: [
          // Approvals lead so a high-risk state is never scrolled away.
          if (onPermissionModeChanged != null) ...[
            perm.PermissionModeSelector(
              selectedMode: permissionMode,
              onModeChanged: onPermissionModeChanged,
              availableModes: sessionFlavor == 'codex'
                  ? perm.PermissionModeExtension.codexModes
                  : perm.PermissionModeExtension.claudeAgyModes,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          ModelChip(
            model: model,
            resolvedLabel: resolvedModelLabel,
            enabled: availableModels.length > 1 || canRefreshModels,
            onTap: onShowModelPicker,
          ),
          if (compact)
            ComposerIconChip(
              key: const ValueKey('composer-options-button'),
              icon: Icons.tune_rounded,
              tooltip: context.l10n.chatComposerOptions,
              onTap: () => _showOptions(context),
            )
          else ...[
            const SizedBox(width: AppSpacing.xs),
            ProfileChip(profile: selectedProfile, onTap: onShowProfilePicker),
          ],
          if (!compact && contextSize != null && contextSize! > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            ContextSizeIndicator(
              contextSize: contextSize!,
              maxContext: maxContext ?? ContextSizeIndicator.defaultMaxContext,
            ),
          ],
        ],
      ),
    );
    // Overflowing settings fade out at the trailing edge instead of being
    // cut mid-glyph against the expand button.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0, math.max(0, (rect.width - _laneFade) / rect.width), 1],
      ).createShader(rect),
      child: lane,
    );
  }

  void _showOptions(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatComposerOptions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz),
                title: Text(
                  selectedProfile?.name ?? l10n.chatInputProfileDefault,
                ),
                subtitle: profileBackendHost(selectedProfile) == null
                    ? null
                    : Text(profileBackendHost(selectedProfile)!),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onShowProfilePicker();
                },
              ),
              if (contextSize != null && contextSize! > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.chatComposerContext),
                  trailing: ContextSizeIndicator(
                    contextSize: contextSize!,
                    maxContext:
                        maxContext ?? ContextSizeIndicator.defaultMaxContext,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
