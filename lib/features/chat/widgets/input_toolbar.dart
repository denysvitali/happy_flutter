import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../model_selection_resolver.dart';
import 'codex_speed_selector.dart';
import 'composer_selector_chip.dart';
import 'model_mode.dart';
import 'permission_mode_selector.dart' as perm;
import 'package:happy_flutter/core/theme/app_text.dart';

/// Inline chip for model selection — subtle, tappable.
class ModelChip extends StatelessWidget {
  const ModelChip({
    required this.model,
    required this.onTap,
    this.enabled = true,
    this.resolvedLabel,
    this.plain = false,
    super.key,
  });

  final ChatModelMode model;
  final VoidCallback onTap;
  final bool enabled;
  final String? resolvedLabel;

  /// Text-only rendering for the mobile status line under the composer.
  final bool plain;

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
      hint: enabled ? null : l10n.chatModelFixed,
      excludeSemantics: true,
      child: Tooltip(
        message: enabled ? l10n.composerModelLabel : l10n.chatModelFixed,
        child: plain
            ? _StatusSegment(
                onTap: enabled ? onTap : null,
                label: value,
                trailingIcon: enabled ? Icons.expand_more_rounded : null,
                strong: true,
              )
            : ComposerSelectorChip(onTap: enabled ? onTap : null, label: value),
      ),
    );
  }
}

/// One tappable piece of the mobile status line: small text with an
/// optional leading/trailing glyph, no pill chrome.
class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    this.color,
    this.strong = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    final style = strong
        ? AppText.label(theme, fg)
        : AppText.secondary(theme, fg);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _statusLineHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: AppIconSize.xs, color: fg),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, size: AppIconSize.xs, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap height of the mobile status line under the composer.
const double _statusLineHeight = 32;

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
    this.showPercentage = false,
    super.key,
  });

  /// Tokens currently occupying the window, or null when no turn has
  /// reported usage yet. A null size still renders [maxContext], so the
  /// window the session runs in stays visible before the first reply.
  final int? contextSize;

  /// The window the [contextSize] is measured against. Reflects the
  /// selected context window (1M vs. the model's default).
  final int? maxContext;
  final bool showPercentage;

  /// Conservative default budget for the standard (non-1M) window.
  static const int defaultMaxContext = 190000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final used = contextSize;
    final window = maxContext;
    // No usage yet: the window size is the only thing to show, and it must
    // not pretend to be a fill level.
    if (used == null) {
      final l10n = context.l10n;
      return Semantics(
        label: l10n.profilesContextWindowTitle,
        value: _tokenLabel(window ?? defaultMaxContext),
        excludeSemantics: true,
        child: Text(
          _tokenLabel(window ?? defaultMaxContext),
          style: AppText.secondary(
            theme,
            cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
      );
    }
    final pctUsed = window != null && window > 0
        ? (used / window * 100).clamp(0.0, 100.0)
        : null;
    final pctRemaining = pctUsed == null ? null : (100 - pctUsed).round();

    final Color indicatorColor;
    if (pctRemaining != null && pctRemaining <= 5) {
      indicatorColor = cs.error;
    } else if (pctRemaining != null && pctRemaining <= 15) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = cs.onSurfaceVariant.withValues(alpha: 0.65);
    }

    final label = _tokenLabel(used);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pctUsed != null) ...[
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
        ],
        Text(
          showPercentage && pctUsed != null
              ? '$label · ${pctUsed.toStringAsFixed(1)}%'
              : label,
          style: AppText.secondary(theme, indicatorColor),
        ),
      ],
    );
  }

  /// Compact token count: `950`, `23k`, `1M`.
  static String _tokenLabel(int tokens) {
    if (tokens >= 1000000 && tokens % 1000000 == 0) {
      return '${tokens ~/ 1000000}M';
    }
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(0)}k';
    return '$tokens';
  }
}

/// Width of the trailing fade on the scrolling settings lane.
const double _laneFade = 16;

/// Gap between neighbouring setting chips.
const double _chipGap = AppSpacing.sm;

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
    this.codexFastMode,
    this.onCodexFastModeChanged,
    this.onShowOptions,
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
  final bool? codexFastMode;
  final ValueChanged<bool>? onCodexFastModeChanged;

  /// Opens the composer's full options sheet. When set, the options
  /// button shows on every layout and replaces the built-in sheet.
  final VoidCallback? onShowOptions;

  /// A turn has reported how full the window is. Prime keeps its row even
  /// at zero, because a cleared snapshot is itself information.
  bool get _contextUsed =>
      contextSize != null &&
      (contextSize! > 0 || sessionFlavor == 'prime-agent');

  /// Something to show: measured usage, or a window the profile actually
  /// chose. The 190k fallback is a guess and stays hidden.
  bool get _contextVisible =>
      _contextUsed || (maxContext != null && maxContext! > 0);

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildStatusLine(context);
    final options = ComposerIconChip(
      key: const ValueKey('composer-options-button'),
      icon: Icons.tune_rounded,
      tooltip: context.l10n.chatComposerOptions,
      onTap: onShowOptions ?? () => _showOptions(context),
    );
    if (sessionFlavor == 'har') {
      final har = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Host · approvals disabled',
              style: AppText.secondary(
                Theme.of(context),
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ModelChip(
              model: modelMode ?? ChatModelMode.defaultModel,
              enabled: availableModels.isNotEmpty,
              resolvedLabel: resolvedModelLabel,
              onTap: onShowModelPicker,
            ),
          ],
        ),
      );
      if (onShowOptions == null) return har;
      return Row(
        children: [
          Flexible(child: har),
          options,
        ],
      );
    }
    final model = modelMode ?? ChatModelMode.defaultModel;

    // Only secondary controls scroll on mobile; approvals and options stay
    // reachable even when the selected model has a long name.
    final lane = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      // Room for the fade so chips that fit are never dimmed.
      padding: const EdgeInsetsDirectional.only(end: _laneFade),
      child: Row(
        children: [
          // Approvals lead so a high-risk state is never scrolled away.
          if (!compact && onPermissionModeChanged != null) ...[
            perm.PermissionModeSelector(
              selectedMode: permissionMode,
              onModeChanged: onPermissionModeChanged,
              availableModes: sessionFlavor == 'codex'
                  ? perm.PermissionModeExtension.codexModes
                  : perm.PermissionModeExtension.claudeAgyModes,
            ),
            const SizedBox(width: _chipGap),
          ],
          ModelChip(
            model: model,
            resolvedLabel: resolvedModelLabel,
            enabled: availableModels.length > 1 || canRefreshModels,
            onTap: onShowModelPicker,
          ),
          if (sessionFlavor == 'codex') ...[
            const SizedBox(width: _chipGap),
            CodexSpeedSelector(
              fastMode: codexFastMode,
              onChanged: onCodexFastModeChanged,
            ),
          ],
          if (!compact) ...[
            const SizedBox(width: _chipGap),
            ProfileChip(profile: selectedProfile, onTap: onShowProfilePicker),
          ],
          if (!compact && _contextVisible) ...[
            const SizedBox(width: AppSpacing.sm),
            ContextSizeIndicator(
              contextSize: _contextUsed ? contextSize : null,
              maxContext: sessionFlavor == 'prime-agent'
                  ? maxContext
                  : maxContext ?? ContextSizeIndicator.defaultMaxContext,
              showPercentage: sessionFlavor == 'prime-agent',
            ),
          ],
        ],
      ),
    );
    // Overflowing settings fade out at the trailing edge instead of being
    // cut mid-glyph against the expand button.
    final scrollingLane = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0, math.max(0, (rect.width - _laneFade) / rect.width), 1],
      ).createShader(rect),
      child: lane,
    );
    if (!compact && onShowOptions == null) return scrollingLane;
    return Row(
      children: [
        Flexible(child: scrollingLane),
        options,
      ],
    );
  }

  /// Mobile: a quiet status line instead of chips. The model switches in
  /// place; everything else opens the composer's options sheet.
  Widget _buildStatusLine(BuildContext context) {
    final l10n = context.l10n;
    final openOptions = onShowOptions ?? () => _showOptions(context);
    final mode = permissionMode ?? perm.PermissionMode.defaultMode;
    final dot = Text(
      '·',
      style: AppText.secondary(
        Theme.of(context),
        Theme.of(context).colorScheme.outline,
      ),
    );
    final showContext = _contextVisible;
    return Row(
      key: const ValueKey('composer-status-line'),
      children: [
        // Model and approvals share the leading space; context stays
        // pinned to the trailing edge under send.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: ModelChip(
                  model: modelMode ?? ChatModelMode.defaultModel,
                  resolvedLabel: resolvedModelLabel,
                  enabled: sessionFlavor == 'har'
                      ? availableModels.isNotEmpty
                      : availableModels.length > 1 || canRefreshModels,
                  onTap: onShowModelPicker,
                  plain: true,
                ),
              ),
              if (sessionFlavor == 'har') ...[
                dot,
                const Flexible(
                  child: _StatusSegment(
                    leadingIcon: Icons.warning_amber_rounded,
                    label: 'Host · approvals disabled',
                    onTap: null,
                  ),
                ),
              ] else if (onPermissionModeChanged != null) ...[
                dot,
                Flexible(
                  child: _StatusSegment(
                    key: const ValueKey('composer-status-approvals'),
                    leadingIcon: mode.icon,
                    label: mode.localizedDisplayName(l10n),
                    color: mode.skipsConfirmation ? mode.color : null,
                    onTap: openOptions,
                  ),
                ),
              ],
              if (sessionFlavor == 'codex' && (codexFastMode ?? false)) ...[
                dot,
                _StatusSegment(
                  leadingIcon: Icons.bolt_rounded,
                  label: l10n.codexSpeedFast,
                  onTap: openOptions,
                ),
              ],
            ],
          ),
        ),
        if (showContext)
          InkWell(
            onTap: openOptions,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _statusLineHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: ContextSizeIndicator(
                    contextSize: _contextUsed ? contextSize : null,
                    maxContext: sessionFlavor == 'prime-agent'
                        ? maxContext
                        : maxContext ?? ContextSizeIndicator.defaultMaxContext,
                    showPercentage: sessionFlavor == 'prime-agent',
                  ),
                ),
              ),
            ),
          ),
      ],
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
              if (_contextVisible)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.chatComposerContext),
                  trailing: ContextSizeIndicator(
                    contextSize: _contextUsed ? contextSize : null,
                    maxContext: sessionFlavor == 'prime-agent'
                        ? maxContext
                        : maxContext ?? ContextSizeIndicator.defaultMaxContext,
                    showPercentage: sessionFlavor == 'prime-agent',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
