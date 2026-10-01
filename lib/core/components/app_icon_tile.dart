import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// The one leading icon tile: a tinted rounded square with a centered glyph.
///
/// Used for settings rows, picker options, banners and info rows so every
/// "icon in a box" is the same shape and size. [size] is an
/// [AppControlSize]; the glyph steps up to [AppIconSize.lg] on the large tile.
///
/// With [neutral] the tile is a quiet grey chip (an unselected option);
/// otherwise it is tinted with [color] (defaulting to the primary color).
class AppIconTile extends StatelessWidget {
  /// Creates an icon tile.
  const AppIconTile({
    required this.icon,
    super.key,
    this.color,
    this.size = AppControlSize.md,
    this.neutral = false,
  });

  /// The glyph.
  final IconData icon;

  /// Accent color for the tint and glyph; defaults to the primary color.
  final Color? color;

  /// Tile edge, one of [AppControlSize]'s values.
  final double size;

  /// Renders the muted, unselected look instead of the accent tint.
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = color ?? cs.primary;
    final tint = dark ? AppOpacity.subtle : AppOpacity.faint;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: neutral
            ? cs.onSurface.withValues(alpha: 0.05)
            : accent.withValues(alpha: tint),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        icon,
        size: size >= AppControlSize.lg ? AppIconSize.lg : AppIconSize.md,
        color: neutral ? cs.onSurfaceVariant : accent,
      ),
    );
  }
}
