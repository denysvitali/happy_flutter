import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../ui/avatars/avatar_brutalist.dart' as canvas_brutalist;
import '../ui/avatars/avatar_constellation.dart';
import '../ui/avatars/avatar_geometric.dart';
import '../ui/avatars/avatar_gradient.dart' as canvas_gradient;
import '../ui/avatars/avatar_rings.dart';
import '../ui/avatars/avatar_wave.dart';

/// Avatar style options
enum AvatarStyle {
  brutalist,
  gradient,
  pixelated,
  geometric,
  rings,
  constellation,
  wave,
}

/// Flavor icon types for AI assistant avatars
enum FlavorIcon {
  claude,
  codex,
  gemini,
}

/// Hash code function for consistent avatar selection based on id
int _avatarHashCode(String str) {
  var hash = 0;
  for (var i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash.abs();
}

/// AvatarBrutalist - Canvas-based brutalist avatar with initials.
///
/// Delegates to the canvas implementation in
/// `lib/core/ui/avatars/avatar_brutalist.dart`. The previous version
/// referenced 420+ PNG asset files that were never bundled on disk,
/// causing every render to silently fall through to an error path.
class AvatarBrutalist extends StatelessWidget {

  const AvatarBrutalist({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return canvas_brutalist.AvatarBrutalist(id: id, size: size);
  }
}

/// AvatarGradient - Canvas-based gradient avatar.
///
/// Delegates to the canvas implementation in
/// `lib/core/ui/avatars/avatar_gradient.dart`. The previous version
/// referenced 100 PNG asset files that were never bundled on disk,
/// causing every render to silently fall through to an error path.
class AvatarGradient extends StatelessWidget {

  const AvatarGradient({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return canvas_gradient.AvatarGradient(id: id, size: size);
  }
}

/// AvatarSkia - 8x8 pixel grid with generative colors
class AvatarSkia extends StatelessWidget {

  const AvatarSkia({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  static const _colorPalette = [
    '#0a0310',
    '#49007e',
    '#ff005b',
    '#ff7d10',
    '#ffb238',
  ];
  static const _grayscalePalette = [
    '#070707',
    '#242424',
    '#575757',
    '#979797',
    '#bbbbbb',
  ];

  @override
  Widget build(BuildContext context) {
    final hash = _avatarHashCode(id);
    final palette = monochrome ? _grayscalePalette : _colorPalette;
    final borderRadius = square ? 0.0 : size / 2;

    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PixelGridPainter(
            id: id,
            hash: hash,
            palette: palette,
            monochrome: monochrome,
          ),
        ),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {

  _PixelGridPainter({
    required this.id,
    required this.hash,
    required this.palette,
    required this.monochrome,
  }) : _colors = _computeColors(hash, palette, monochrome);

  final String id;
  final int hash;
  final List<String> palette;
  final bool monochrome;
  final List<Color> _colors;

  static List<Color> _computeColors(
    int hash,
    List<String> palette,
    bool monochrome,
  ) {
    final colors = <Color>[];
    for (var index = 0; index < 64; index++) {
      final color = _colorForIndex(hash, palette, monochrome, index);
      colors.add(color);
    }
    return colors;
  }

  static Color _colorForIndex(
    int hash,
    List<String> palette,
    bool monochrome,
    int index,
  ) {
    if (monochrome) {
      final colorHash = (hash + index) % palette.length;
      final colorStr = palette[colorHash];
      return _parseColor(colorStr);
    }

    // Generate varied colors using golden angle + HSL
    final hue = ((hash + index * 137.508) % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.65).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 8;

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final index = row * 8 + col;
        final paint = Paint()..color = _colors[index];
        final rect = Rect.fromLTWH(
          col * cellSize,
          row * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  static Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hex = colorStr.substring(1);
      return Color(int.parse(hex, radix: 16) | 0xFF000000);
    }

    return Colors.grey;
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) =>
      oldDelegate.hash != hash ||
      oldDelegate.monochrome != monochrome ||
      oldDelegate.palette != palette;
}

/// Flavor icon overlay widget for AI assistant avatars
class FlavorIconOverlay extends StatelessWidget {

  const FlavorIconOverlay({
    required this.flavor,
    required this.avatarSize,
    this.showBackground = true,
    super.key,
  });
  final FlavorIcon flavor;
  final double avatarSize;
  final bool showBackground;

  String get _iconPath {
    switch (flavor) {
      case FlavorIcon.claude:
        return 'assets/images/icon-claude.png';
      case FlavorIcon.codex:
        return 'assets/images/icon-gpt.png';
      case FlavorIcon.gemini:
        return 'assets/images/icon-gemini.png';
    }
  }

  double get _iconSize {
    switch (flavor) {
      case FlavorIcon.claude:
        return avatarSize * 0.28;
      case FlavorIcon.codex:
        return avatarSize * 0.25;
      case FlavorIcon.gemini:
        return avatarSize * 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    final circleSize = (avatarSize * 0.35).round();

    return Container(
      width: circleSize.toDouble(),
      height: circleSize.toDouble(),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Image.asset(
        _iconPath,
        width: _iconSize,
        height: _iconSize,
        cacheWidth:
            (_iconSize * MediaQuery.devicePixelRatioOf(context)).round(),
        cacheHeight:
            (_iconSize * MediaQuery.devicePixelRatioOf(context)).round(),
        fit: BoxFit.contain,
        color: flavor == FlavorIcon.codex
            ? Theme.of(context).colorScheme.onSurface
            : null,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Main Avatar widget with support for all styles and image override
class Avatar extends StatelessWidget {

  const Avatar({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    this.flavor,
    this.imageUrl,
    this.thumbhash,
    this.style = AvatarStyle.brutalist,
    this.showFlavorIcon = false,
    super.key,
  });
  final String id;
  final double size;
  final bool square;
  final bool monochrome;
  final FlavorIcon? flavor;
  final String? imageUrl;
  final String? thumbhash;
  final AvatarStyle style;
  final bool showFlavorIcon;

  @override
  Widget build(BuildContext context) {
    // If image URL is provided, show custom image
    if (imageUrl != null) {
      return _buildImageAvatar(context);
    }

    // Otherwise show generated avatar
    final avatarWidget = switch (style) {
      AvatarStyle.brutalist => AvatarBrutalist(
          id: id,
          size: size,
          square: square,
          monochrome: monochrome,
        ),
      AvatarStyle.gradient => AvatarGradient(
          id: id,
          size: size,
          square: square,
          monochrome: monochrome,
        ),
      AvatarStyle.pixelated => AvatarSkia(
          id: id,
          size: size,
          square: square,
          monochrome: monochrome,
        ),
      AvatarStyle.geometric => AvatarGeometric(
          id: id,
          size: size,
        ),
      AvatarStyle.rings => AvatarRings(
          id: id,
          size: size,
        ),
      AvatarStyle.constellation => AvatarConstellation(
          id: id,
          size: size,
        ),
      AvatarStyle.wave => AvatarWave(
          id: id,
          size: size,
        ),
    };

    if (showFlavorIcon && flavor != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            bottom: -2,
            right: -2,
            child: FlavorIconOverlay(
              flavor: flavor!,
              avatarSize: size,
            ),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildImageAvatar(BuildContext context) {
    final borderRadius = square ? 0.0 : size / 2;
    final cacheSize = (size *
        MediaQuery.devicePixelRatioOf(context)).toInt();
    final imageElement = ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (showFlavorIcon && flavor != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          imageElement,
          Positioned(
            bottom: -2,
            right: -2,
            child: FlavorIconOverlay(
              flavor: flavor!,
              avatarSize: size,
            ),
          ),
        ],
      );
    }

    return imageElement;
  }
}
