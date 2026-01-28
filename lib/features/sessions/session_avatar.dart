import 'package:flutter/material.dart';
import '../../core/ui/avatars/avatar.dart';
import '../../core/ui/avatars/avatar_gradient.dart';
import '../../core/ui/avatars/avatar_pixelated.dart';
import '../../core/ui/avatars/avatar_brutalist.dart';

/// Avatar style options for session avatars.
enum AvatarStyle {
  gradient,
  pixelated,
  brutalist,
}

/// AI provider flavors for flavor icon display.
enum AiFlavor {
  claude,
  codex,
  gemini,
}

/// Session avatar widget that supports custom images, multiple styles,
/// and AI provider flavor icons.
///
/// Matches the React Native Avatar.tsx implementation.
class SessionAvatar extends StatelessWidget {
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

  const SessionAvatar({
    super.key,
    required this.id,
    this.imageUrl,
    this.thumbhash,
    this.flavor,
    this.style,
    this.size = 48,
    this.showFlavorIcon = true,
    this.square = false,
    this.monochrome = false,
  });

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

    final avatarWidget = ClipRRect(
      borderRadius: square ? BorderRadius.zero : BorderRadius.circular(size / 2),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(context),
      ),
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

    // Determine which avatar style to use
    final AvatarStyle usedStyle = style ?? _getStyleFromHash();

    final Widget avatarWidget = switch (usedStyle) {
      AvatarStyle.gradient => AvatarGradient(id: id, size: size),
      AvatarStyle.pixelated => AvatarPixelated(id: id, size: size),
      AvatarStyle.brutalist => AvatarBrutalist(id: id, size: size),
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
    final isCodex = flavorName == 'codex';

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          width: circleSize.toDouble(),
          height: circleSize.toDouble(),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
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
      _ => 'assets/images/icon-claude.png',
    };
  }

  IconData _getFlavorIcon(String flavorName) {
    return switch (flavorName) {
      'claude' => Icons.auto_awesome,
      'codex' => Icons.code,
      'gemini' => Icons.sparkles,
      _ => Icons.auto_awesome,
    };
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final usedStyle = style ?? _getStyleFromHash();
    return switch (usedStyle) {
      AvatarStyle.gradient => AvatarGradient(id: id, size: size),
      AvatarStyle.pixelated => AvatarPixelated(id: id, size: size),
      AvatarStyle.brutalist => AvatarBrutalist(id: id, size: size),
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
