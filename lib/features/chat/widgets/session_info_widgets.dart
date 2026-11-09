import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../../sessions/harness_logo.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// Status chip showing online/offline indicator.
class StatusChip extends StatelessWidget {
  /// Creates a [StatusChip].
  const StatusChip({required this.isActive, super.key});

  /// Whether the session is active (online).
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // Same AppBadge shell as every other session pill, so the status and
    // sandbox pills share one height, radius and type role.
    final tone = isActive ? AppBadgeTone.success : AppBadgeTone.neutral;
    final l10n = AppLocalizations.of(context);
    return AppBadge(
      tone: tone,
      label: isActive ? l10n.sessionInfoActive : l10n.sessionInfoInactive,
      leading: AppStatusDot(
        color: AppToneColors.of(context, tone).iconColor,
        size: AppSpacing.xsm,
      ),
    );
  }
}

/// Presence-safe status for the isolation actually applied to this session.
///
/// Legacy sessions do not publish enforcement fields, so no claim is made for
/// them. The requested policy alone is never presented as proof of isolation.
class SessionSandboxBadge extends StatelessWidget {
  /// Creates a badge from daemon-published session metadata.
  const SessionSandboxBadge({required this.metadata, super.key});

  /// Session metadata containing the sandbox enforcement result.
  final Metadata metadata;

  @override
  Widget build(BuildContext context) {
    final requested = metadata.sandboxRequested;
    final enforced = metadata.sandboxEnforced;
    if (requested == null && enforced == null) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final String label;
    final String tooltip;
    final AppBadgeTone tone;
    if (enforced ?? false) {
      label = l10n.sessionSandboxEnforced;
      final backend = metadata.sandboxBackend?.trim();
      tooltip = backend == null || backend.isEmpty
          ? l10n.sessionSandboxEnforcedTooltip('sandbox')
          : l10n.sessionSandboxEnforcedTooltip(backend);
      tone = AppBadgeTone.success;
    } else if (requested ?? false) {
      label = l10n.sessionSandboxNotEnforced;
      final reason = metadata.sandboxReason?.trim();
      tooltip = reason == null || reason.isEmpty
          ? l10n.sessionSandboxNotEnforcedTooltip
          : reason;
      tone = (metadata.sandboxRequired ?? false)
          ? AppBadgeTone.danger
          : AppBadgeTone.warning;
    } else {
      label = l10n.sessionSandboxOff;
      tooltip = l10n.sessionSandboxOffTooltip;
      tone = AppBadgeTone.neutral;
    }

    return Tooltip(
      message: tooltip,
      child: AppBadge(label: label, tone: tone),
    );
  }
}

/// A label/value row on the settings row geometry ([SettingsInfoRow]).
///
/// Stacked by default (label above a full-width value) for IDs and paths;
/// [inline] puts a short value on the trailing edge.
class InfoRow extends StatelessWidget {
  /// Creates an [InfoRow].
  const InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.onTap,
    this.iconColor,
    this.inline = false,
    this.mono = false,
  });

  /// The leading icon.
  final IconData icon;

  /// The label text.
  final String label;

  /// The value text.
  final String value;

  /// Optional tap callback (copies the value; shows a copy glyph).
  final VoidCallback? onTap;

  /// Optional override for the icon color.
  final Color? iconColor;

  /// Short value on the trailing edge instead of under the label.
  final bool inline;

  /// Monospace value (IDs, versions, paths).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return SettingsInfoRow(
      icon: icon,
      label: label,
      value: value,
      iconColor: iconColor,
      stacked: !inline,
      mono: mono,
      onCopy: onTap,
    );
  }
}

/// A tappable action row (Quick actions, pod controls, Copy metadata):
/// a tinted icon tile and a coloured label, on the settings row geometry.
class ActionRow extends StatelessWidget {
  /// Creates an [ActionRow].
  const ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
    this.onTap,
    this.isLoading = false,
  });

  /// The leading icon.
  final IconData icon;

  /// The label text.
  final String label;

  /// The color for icon, text, and trailing element.
  final Color color;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Whether to show a loading spinner.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Opacity(
          opacity: enabled || isLoading ? 1 : AppMotion.disabledContentOpacity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.comfortable,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SettingsIconContainer(icon: icon, color: color),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox.square(
                      dimension: AppIconSize.md,
                      child: AppCircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: AppSpacing.xl,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: AppOpacity.medium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Identity header: harness mark, name, path and status pills, on the
/// same card surface as every section below it.
class SessionInfoHeader extends StatelessWidget {
  const SessionInfoHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.flavor,
    required this.badges,
  });

  final String name;
  final String subtitle;
  final String? flavor;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SettingsSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppControlSize.lg,
                height: AppControlSize.lg,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: HarnessLogo(flavor: flavor ?? '', size: AppIconSize.xxl),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.title(theme),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: badges,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
