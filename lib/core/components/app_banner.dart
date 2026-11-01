import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_badge.dart';

/// A toned, full-width alert: icon, title, optional message and trailing
/// affordance inside a rounded, hairline-bordered panel.
///
/// The single shell for inline warnings and notices, so every alert shares
/// one geometry (radius, padding, icon size, type roles) and the same
/// [AppToneColors] palette as [AppBadge] — a warning banner and a warning
/// pill are always the same hue.
class AppBanner extends StatelessWidget {
  /// Creates an [AppBanner].
  const AppBanner({
    required this.tone,
    required this.title,
    super.key,
    this.message,
    this.icon,
    this.trailing,
    this.onTap,
    this.footer,
  });

  /// Semantic appearance; also supplies the default [icon].
  final AppBadgeTone tone;

  /// One-line headline.
  final String title;

  /// Optional supporting text below [title].
  final String? message;

  /// Overrides the tone's default glyph.
  final IconData? icon;

  /// Optional widget at the end of the row (e.g. a copy glyph). An [Icon]
  /// picks up the tone's icon color and size.
  final Widget? trailing;

  /// Makes the whole banner tappable.
  final VoidCallback? onTap;

  /// Optional content below [message] (e.g. an action button).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppToneColors.of(context, tone);
    final glyph = icon ?? colors.icon ?? Icons.info_outline_rounded;
    final radius = BorderRadius.circular(AppRadius.lg);

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: IconTheme.merge(
        data: IconThemeData(color: colors.iconColor, size: AppIconSize.xl),
        child: Row(
          crossAxisAlignment: message == null && footer == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Icon(glyph),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppText.title(theme, colors.foreground)),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      message!,
                      style: AppText.secondary(theme, colors.foreground),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    footer!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconTheme.merge(
                data: const IconThemeData(size: AppIconSize.md),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: colors.border.withValues(alpha: 0.35),
          width: AppBorder.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
