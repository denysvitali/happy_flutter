import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Shared typography for compact headers, status rows and their actions.
abstract final class AppInlineText {
  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

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

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      key: primaryActionKey,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
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
        style: AppInlineText.body(context),
        child: IconTheme.merge(
          data: IconThemeData(
            size: AppIconSize.md,
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

/// A row action with the same typography and 44px target everywhere.
class AppInlineAction extends StatelessWidget {
  const AppInlineAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.iconOnly = false,
    this.color,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconOnly;
  final Color? color;
  final Key? buttonKey;

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
            width: AppTouchTarget.min,
            height: AppTouchTarget.min,
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
        textStyle: AppInlineText.title(context),
        minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.md),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(label),
        ],
      ),
    );
  }
}
