import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_badge.dart';

export 'app_badge.dart' show AppBadgeTone, AppToneColors;

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
    super.key,
    this.title,
    this.message,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.footer,
    this.elevated = false,
  }) : assert(title != null || message != null, 'Needs a title or message.');

  /// Semantic appearance; also supplies the default [icon].
  final AppBadgeTone tone;

  /// Bold headline; omit for a single plain-text alert.
  final String? title;

  /// Supporting text, or the whole alert when [title] is null.
  final String? message;

  /// Overrides the tone's default glyph.
  final IconData? icon;

  /// Replaces the glyph entirely (e.g. a progress spinner while checking).
  final Widget? leading;

  /// Optional widget at the end of the row (e.g. a copy glyph). A bare
  /// [Icon] picks up the banner's text color.
  final Widget? trailing;

  /// Makes the whole banner tappable.
  final VoidCallback? onTap;

  /// Optional content below [message] (e.g. an action button).
  final Widget? footer;

  /// Floats the banner with a low shadow — for chat chrome that overlays
  /// scrolling content.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppToneColors.of(context, tone);
    final glyph = icon ?? colors.icon ?? Icons.info_outline_rounded;
    final radius = BorderRadius.circular(AppRadius.lg);

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: IconTheme.merge(
        // Icons take the text color: a saturated hue on its own container
        // fails non-text contrast; the container already carries the tone.
        data: IconThemeData(color: colors.foreground, size: AppIconSize.xl),
        child: Row(
          crossAxisAlignment: title != null && message != null || footer != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: AppIconSize.xl,
              child: Center(child: leading ?? Icon(glyph)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: AppText.title(theme, colors.foreground),
                    ),
                  if (message != null) ...[
                    if (title != null) const SizedBox(height: AppSpacing.xxs),
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
      elevation: elevated ? AppElevation.low : 0,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.outline, width: AppBorder.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
