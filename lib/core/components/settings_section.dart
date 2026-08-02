import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Edge length of the leading icon container in a settings row.
const double kSettingsIconContainerSize = 36;

/// Minimum row height when a subtitle is present. Rows grow beyond this
/// at large text scales — the constraint is a floor, never a cap.
const double kSettingsRowMinHeightWithSubtitle = 56;

/// 36x36 rounded icon container used as the leading widget in settings rows.
///
/// Uses a tinted background derived from the icon colour for a modern,
/// iOS-style grouped settings look.
class SettingsIconContainer extends StatelessWidget {
  const SettingsIconContainer({required this.icon, this.color, super.key});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? cs.primary;
    final bgAlpha = dark
        ? AppOpacity
              .subtle // 0.12
        : AppOpacity.faint; // 0.08

    return Container(
      width: kSettingsIconContainerSize,
      height: kSettingsIconContainerSize,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: AppIconSize.lg, color: effectiveColor),
    );
  }
}

/// Above this text scale factor the ellipsis caps on settings-row labels are
/// lifted so the text wraps and the row grows instead of truncating.
const double _kUnclampedTextScale = 1.3;

/// Line cap for row labels: 2 at normal scale (keeps rows tidy), unlimited
/// once the user has enlarged system text.
int? _labelMaxLines(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(AppFontSize.md);
  return scale > AppFontSize.md * _kUnclampedTextScale ? null : 2;
}

/// A simple settings row: icon container + title/subtitle + optional trailing.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxLines = _labelMaxLines(context);
    final sub = subtitle;
    final semanticsLabel = sub == null || sub.isEmpty
        ? title
        : context.l10n.a11ySettingsRow(title, sub);

    void handleTap() {
      HapticFeedback.selectionClick();
      onTap!();
    }

    final row = InkWell(
      onTap: onTap == null ? null : handleTap,
      // The row's label and tap action live on the Semantics node below;
      // letting InkWell publish a second unlabelled tappable node would
      // duplicate the row for screen-reader users.
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: subtitle != null
              ? kSettingsRowMinHeightWithSubtitle
              : AppTouchTarget.comfortable,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SettingsIconContainer(icon: icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              // The title and subtitle are folded into the row node's
              // label, so their own nodes are dropped. Only the label
              // copy is excluded — `trailing` keeps its semantics.
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: maxLines,
                        overflow: maxLines == null
                            ? TextOverflow.clip
                            : TextOverflow.ellipsis,
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          sub,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: maxLines,
                          overflow: maxLines == null
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                // Deliberately not Flexible: a second flex child would
                // halve the label column's width at every text scale.
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );

    // One node for the label-bearing part of the row (leading icon, title
    // and subtitle), instead of the fragments the plain container produced.
    // Deliberately NOT MergeSemantics: real call sites put IconButtons in
    // `trailing` (duplicate/edit/delete, download, preview) and merging
    // would swallow them into this node — unreachable for a screen reader,
    // with their tap actions overwritten by the row's own.
    return Semantics(
      button: onTap != null,
      enabled: onTap != null ? true : null,
      container: true,
      label: semanticsLabel,
      onTap: onTap == null ? null : handleTap,
      child: row,
    );
  }
}

/// A settings row with a Switch.adaptive trailing widget.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxLines = _labelMaxLines(context);
    final l10n = context.l10n;

    return MergeSemantics(
      child: Semantics(
        button: true,
        toggled: value,
        enabled: true,
        container: true,
        value: value ? l10n.a11ySettingsRowOn : l10n.a11ySettingsRowOff,
        onTap: () => onChanged(!value),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: subtitle != null
                  ? kSettingsRowMinHeightWithSubtitle
                  : AppTouchTarget.comfortable,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SettingsIconContainer(icon: icon, color: iconColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: maxLines,
                          overflow: maxLines == null
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: maxLines,
                            overflow: maxLines == null
                                ? TextOverflow.clip
                                : TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Switch.adaptive(
                      value: value,
                      onChanged: onChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// A settings row that navigates somewhere - includes a right chevron.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right,
        size: AppSpacing.xl,
        textDirection: Directionality.of(context),
        color: cs.onSurface.withValues(alpha: AppOpacity.medium),
      ),
    );
  }
}

/// Settings section wrapper with optional title, description,
/// and dividers between children.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    super.key,
    this.title,
    this.description,
    this.uppercase = true,
    this.danger = false,
  });

  /// Optional section heading text.
  final String? title;

  /// Optional description shown below the section card.
  final String? description;

  /// Whether to force the title to uppercase. Defaults to true.
  final bool uppercase;

  /// When true, renders a red-tinted border to indicate a
  /// destructive section (e.g. sign-out, delete account).
  final bool danger;

  /// Child widgets rendered inside the section card.
  final List<Widget> children;

  // Leading padding (16) + icon container width (36) + gap (12).
  static const double _dividerIndent =
      AppSpacing.lg + kSettingsIconContainerSize + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = danger
        ? cs.error.withValues(alpha: AppOpacity.half)
        : cs.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            // Announced as a heading so screen-reader users can jump
            // between settings sections instead of reading every row.
            child: Semantics(
              header: true,
              label: title,
              child: ExcludeSemantics(
                child: Text(
                  uppercase ? title!.toUpperCase() : title!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: danger ? cs.error : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        Card(
          color: cs.surfaceContainerLow,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: borderColor),
          ),
          child: Column(children: _intersperse(children, cs)),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              top: AppSpacing.xs,
            ),
            child: Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// Inserts a slim divider between children (but not before/after).
  List<Widget> _intersperse(List<Widget> items, ColorScheme cs) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: AppBorder.hairline,
            indent: _dividerIndent,
            endIndent: 0,
            color: cs.outlineVariant,
          ),
        );
      }
    }
    return result;
  }
}
