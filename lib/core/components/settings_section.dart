import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// 36x36 rounded icon container used as the leading widget in settings rows.
///
/// Uses a tinted background derived from the icon colour for a modern,
/// iOS-style grouped settings look.
class SettingsIconContainer extends StatelessWidget {
  const SettingsIconContainer({
    required this.icon,
    this.color,
    super.key,
  });

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? cs.primary;
    final bgAlpha = dark
        ? AppOpacity.subtle  // 0.12
        : AppOpacity.faint;  // 0.08

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: 18, color: effectiveColor),
    );
  }
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

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: subtitle != null ? null : 48,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
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

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
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
      AppSpacing.lg + 36 + AppSpacing.md;

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
            child: Text(
              uppercase ? title!.toUpperCase() : title!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: danger ? cs.error : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: borderColor),
          ),
          child: Column(
            children: _intersperse(children, cs),
          ),
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
  List<Widget> _intersperse(
    List<Widget> items,
    ColorScheme cs,
  ) {
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
