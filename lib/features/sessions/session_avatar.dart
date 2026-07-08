import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/avatars/avatar_bloom.dart';
import '../../core/ui/avatars/avatar_brutalist.dart';
import '../../core/ui/avatars/avatar_constellation.dart';
import '../../core/ui/avatars/avatar_geometric.dart';
import '../../core/ui/avatars/avatar_gradient.dart';
import '../../core/ui/avatars/avatar_neon.dart';
import '../../core/ui/avatars/avatar_pixelated.dart';
import '../../core/ui/avatars/avatar_prism.dart';
import '../../core/ui/avatars/avatar_rings.dart';
import '../../core/ui/avatars/avatar_wave.dart';
import '../../core/widgets/network_avatar_image.dart';

/// Avatar style options for session avatars.
enum AvatarStyle {
  gradient,
  pixelated,
  brutalist,
  geometric,
  rings,
  constellation,
  wave,
  neon,
  bloom,
  prism,
}

/// Session avatar widget that supports custom images, multiple styles,
/// and AI provider flavor icons.
///
/// Matches the React Native Avatar.tsx implementation.
class SessionAvatar extends StatelessWidget {
  const SessionAvatar({
    required this.id,
    super.key,
    this.imageUrl,
    this.thumbhash,
    this.flavor,
    this.style,
    this.size = 48,
    this.showFlavorIcon = true,
    this.square = false,
    this.monochrome = false,
  });

  /// The unique ID used to generate consistent avatar colors and selection.
  final String id;

  /// Optional custom image URL to display instead of generated avatar.
  final String? imageUrl;

  /// Optional thumbhash for progressive image loading.
  final String? thumbhash;

  /// The AI provider flavor (claude, codex, gemini) for the flavor icon.
  final String? flavor;

  /// The avatar style to use (defaults to hash-based rotation).
  final AvatarStyle? style;

  /// Size of the avatar in logical pixels.
  final double size;

  /// Whether to show the AI provider flavor icon.
  final bool showFlavorIcon;

  /// Whether to use a square shape instead of circular.
  final bool square;

  /// Whether to render in monochrome mode.
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    // Render custom image if provided
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildImageAvatar(context);
    }

    // Otherwise render generated avatar
    return _buildGeneratedAvatar(context);
  }

  Widget _buildImageAvatar(BuildContext context) {
    final effectiveFlavor = flavor ?? 'claude';
    final effectiveSize = size.toInt();
    final circleSize = (effectiveSize * 0.35).round();
    final iconSize = effectiveFlavor == 'codex'
        ? (effectiveSize * 0.25).round()
        : effectiveFlavor == 'claude'
        ? (effectiveSize * 0.28).round()
        : (effectiveSize * 0.35).round();

    final avatarWidget = NetworkAvatarImage(
      url: imageUrl!,
      size: size,
      square: square,
      fallback: _buildFallbackAvatar(context),
    );

    if (showFlavorIcon && flavor != null) {
      return Stack(
        children: [
          SizedBox(width: size, height: size, child: avatarWidget),
          Positioned(
            bottom: -2,
            right: -2,
            child: _buildFlavorIcon(effectiveFlavor, circleSize, iconSize),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildGeneratedAvatar(BuildContext context) {
    final effectiveFlavor = flavor ?? 'claude';
    final effectiveSize = size.toInt();
    final circleSize = (effectiveSize * 0.35).round();
    final iconSize = effectiveFlavor == 'codex'
        ? (effectiveSize * 0.25).round()
        : effectiveFlavor == 'claude'
        ? (effectiveSize * 0.28).round()
        : (effectiveSize * 0.35).round();

    final effectiveStyle = style ?? _getStyleFromHash();
    final rawAvatar = switch (effectiveStyle) {
      AvatarStyle.gradient => AvatarGradient(id: id, size: size),
      AvatarStyle.pixelated => AvatarPixelated(id: id, size: size),
      AvatarStyle.brutalist => AvatarBrutalist(id: id, size: size),
      AvatarStyle.geometric => AvatarGeometric(id: id, size: size),
      AvatarStyle.rings => AvatarRings(id: id, size: size),
      AvatarStyle.constellation => AvatarConstellation(id: id, size: size),
      AvatarStyle.wave => AvatarWave(id: id, size: size),
      AvatarStyle.neon => AvatarNeon(id: id, size: size),
      AvatarStyle.bloom => AvatarBloom(id: id, size: size),
      AvatarStyle.prism => AvatarPrism(id: id, size: size),
    };
    // Wrap CustomPaint-based avatars in RepaintBoundary so they are not
    // redrawn when the parent session card repaints (hover, presence, typing).
    final avatarWidget = switch (effectiveStyle) {
      AvatarStyle.geometric ||
      AvatarStyle.rings ||
      AvatarStyle.constellation ||
      AvatarStyle.wave ||
      AvatarStyle.neon ||
      AvatarStyle.bloom ||
      AvatarStyle.prism => RepaintBoundary(child: rawAvatar),
      _ => rawAvatar,
    };

    if (showFlavorIcon && flavor != null) {
      return Stack(
        children: [
          avatarWidget,
          Positioned(
            bottom: -2,
            right: -2,
            child: _buildFlavorIcon(effectiveFlavor, circleSize, iconSize),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildFlavorIcon(String flavorName, int circleSize, int iconSize) {
    final iconPath = _getFlavorIconPath(flavorName);
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          width: circleSize.toDouble(),
          height: circleSize.toDouble(),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            // cs.shadow follows the M3 theme — light in light mode,
            // dark in dark mode. The previous Colors.black.withValues
            // (alpha: 0.15) was always-on-top black regardless of theme.
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow
                    .withValues(alpha: AppOpacity.soft),
                offset: const Offset(0, 1),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              iconPath,
              width: iconSize.toDouble(),
              height: iconSize.toDouble(),
              cacheWidth: (iconSize * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              cacheHeight: (iconSize * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image fails
                return Icon(
                  _getFlavorIcon(flavorName),
                  size: iconSize.toDouble() * 0.7,
                  color: theme.colorScheme.onSurface,
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getFlavorIconPath(String flavorName) {
    return switch (flavorName) {
      'claude' => 'assets/images/icon-claude.png',
      'codex' => 'assets/images/icon-gpt.png',
      'gemini' => 'assets/images/icon-gemini.png',
      'pi' => 'assets/images/icon-pi.png',
      'opencode' => 'assets/images/icon-gpt.png',
      // No dedicated Grok asset yet; reuse the GPT icon as a neutral stand-in.
      'grok' || 'grok-build' => 'assets/images/icon-gpt.png',
      _ => 'assets/images/icon-claude.png',
    };
  }

  IconData _getFlavorIcon(String flavorName) {
    return switch (flavorName) {
      'claude' => Icons.auto_awesome,
      'codex' => Icons.code,
      'gemini' => Icons.auto_awesome,
      'pi' => Icons.psychology_alt_outlined,
      'opencode' => Icons.smart_toy_outlined,
      'grok' || 'grok-build' => Icons.rocket_launch_outlined,
      _ => Icons.auto_awesome,
    };
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final usedStyle = style ?? _getStyleFromHash();
    return switch (usedStyle) {
      AvatarStyle.gradient => AvatarGradient(id: id, size: size),
      AvatarStyle.pixelated => AvatarPixelated(id: id, size: size),
      AvatarStyle.brutalist => AvatarBrutalist(id: id, size: size),
      AvatarStyle.geometric => AvatarGeometric(id: id, size: size),
      AvatarStyle.rings => AvatarRings(id: id, size: size),
      AvatarStyle.constellation => AvatarConstellation(id: id, size: size),
      AvatarStyle.wave => AvatarWave(id: id, size: size),
      AvatarStyle.neon => AvatarNeon(id: id, size: size),
      AvatarStyle.bloom => AvatarBloom(id: id, size: size),
      AvatarStyle.prism => AvatarPrism(id: id, size: size),
    };
  }

  /// Determines avatar style based on ID hash for consistent selection.
  AvatarStyle _getStyleFromHash() {
    final hash = _hashCode(id);
    return AvatarStyle.values[hash % AvatarStyle.values.length];
  }

  /// Computes a consistent hash code from a string.
  ///
  /// Uses the same algorithm as the React Native implementation:
  /// hash = ((hash << 5) - hash) + char, then takes absolute value.
  int _hashCode(String str) {
    var hash = 0;
    for (final char in str.runes) {
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs();
  }
}

/// Creates a [SessionAvatar] for a session with proper flavor handling.
SessionAvatar createSessionAvatar(
  String avatarId, {
  String? flavor,
  double size = 48,
  bool showFlavorIcon = true,
}) {
  return SessionAvatar(
    id: avatarId,
    flavor: flavor,
    size: size,
    showFlavorIcon: showFlavorIcon,
  );
}
