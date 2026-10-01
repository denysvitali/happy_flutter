import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Shared typography for compact headers, status rows and their actions.
///
/// Chrome text steps down from the 14sp draft and transcript body: rows are
/// 13sp ([AppFontSize.md]) and selector chips are 12sp ([AppFontSize.sm]), so
/// the composer, not its surroundings, is the largest type on screen.
abstract final class AppInlineText {
  static TextStyle body(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(fontSize: AppFontSize.md);

  /// Composer chrome: selector pills and the task / activity rows above the
  /// composer. One small, quiet style (11sp regular, muted) so the chrome is
  /// clearly secondary to the 14sp draft.
  static TextStyle chrome(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium!.copyWith(
      fontSize: AppFontSize.xs,
      fontWeight: FontWeight.w400,
      height: 1.3,
      letterSpacing: 0,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// [chrome] for the one emphasized word in a row (its title or action).
  static TextStyle chromeStrong(BuildContext context) => chrome(context)
      .copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Label inside a composer selector chip.
  static TextStyle chip(BuildContext context) => chrome(context);

  static TextStyle title(BuildContext context) =>
      body(context).copyWith(fontWeight: FontWeight.w500);

  static TextStyle secondary(BuildContext context) => body(
    context,
  ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
}

/// A flat, reusable row with aligned icons, readable text and touch targets.
/// [action] is outside the primary tap target, so Copy, Stop and Details
/// never trigger the row's expand/navigation action.
class AppInlineRow extends StatelessWidget {
  const AppInlineRow({
    required this.leading,
    required this.child,
    super.key,
    this.trailing,
    this.action,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.expanded,
    this.primaryActionKey,
    this.backgroundColor,
    this.dense = false,
  });

  final Widget leading;
  final Widget child;
  final Widget? trailing;
  final Widget? action;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? expanded;
  final Key? primaryActionKey;
  final Color? backgroundColor;

  /// Composer-chrome density: a [AppControlSize.sm] tall row with
  /// [AppInlineText.chrome] text. Pair with a dense [AppInlineAction].
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      key: primaryActionKey,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: dense ? AppControlSize.sm : AppRowHeight.compact,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: AppIconSize.md,
                child: Center(child: leading),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );

    return Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: dense
            ? AppInlineText.chrome(context)
            : AppInlineText.body(context),
        child: IconTheme.merge(
          data: IconThemeData(
            size: dense ? AppIconSize.sm : AppIconSize.md,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Row(
            children: [
              Expanded(
                child: semanticLabel == null
                    ? content
                    : Semantics(
                        button: onTap != null,
                        enabled: onTap != null,
                        expanded: expanded,
                        label: semanticLabel,
                        hint: semanticHint,
                        onTap: onTap,
                        onLongPress: onLongPress,
                        child: ExcludeSemantics(child: content),
                      ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// A row action with the same typography and [AppRowHeight.compact] target
/// everywhere, so an action never makes its row taller than its neighbours.
class AppInlineAction extends StatelessWidget {
  const AppInlineAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.iconOnly = false,
    this.color,
    this.buttonKey,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconOnly;
  final Color? color;
  final Key? buttonKey;

  /// Composer-chrome density; see [AppInlineRow.dense].
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Semantics(
        label: label,
        button: true,
        enabled: onPressed != null,
        onTap: onPressed,
        excludeSemantics: true,
        child: IconButton(
          key: buttonKey,
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, size: AppIconSize.md),
          color: color,
          constraints: const BoxConstraints.tightFor(
            width: AppRowHeight.compact,
            height: AppRowHeight.compact,
          ),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: dense
            ? AppInlineText.chromeStrong(context)
            : AppInlineText.title(context),
        minimumSize: dense
            ? const Size(AppControlSize.sm, AppControlSize.sm)
            : const Size(AppRowHeight.compact, AppRowHeight.compact),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? AppIconSize.sm : AppIconSize.md),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(label),
        ],
      ),
    );
  }
}
