import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Avatar style options
enum AvatarStyle {
  brutalist,
  gradient,
  pixelated,
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

/// Generate a color from a number using golden angle for nice distribution
String _generateColor(int number, bool monochrome) {
  if (monochrome) {
    const grayColors = ['#070707', '#242424', '#575757', '#979797', '#bbbbbb'];
    return grayColors[number % grayColors.length];
  }

  const hue = (number * 137.508) % 360;
  return 'hsl(${hue.toInt()}, 45%, 65%)';
}

/// Convert HSL color to grayscale
String _hslToGrayscale(String hslColor) {
  final match = RegExp(r'hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)').firstMatch(hslColor);
  if (match == null) return hslColor;
  return 'hsl(0, 0%, ${match.group(3)}%)';
}

/// AvatarBrutalist - Uses abstract/bauhaus/brutalist style images with color pairs
class AvatarBrutalist extends StatelessWidget {
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  const AvatarBrutalist({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });

  static const _abstractImages = [
    'assets/images/brutalist/Abstract 1.png',
    'assets/images/brutalist/Abstract 2.png',
    'assets/images/brutalist/Abstract 3.png',
    'assets/images/brutalist/Abstract 4.png',
    'assets/images/brutalist/Abstract 5.png',
    'assets/images/brutalist/Abstract 6.png',
    'assets/images/brutalist/Abstract 7.png',
    'assets/images/brutalist/Abstract 8.png',
    'assets/images/brutalist/Abstract 9.png',
    'assets/images/brutalist/Abstract 10.png',
    'assets/images/brutalist/Abstract 11.png',
    'assets/images/brutalist/Abstract 12.png',
    'assets/images/brutalist/Abstract 13.png',
    'assets/images/brutalist/Abstract 14.png',
    'assets/images/brutalist/Abstract 15.png',
    'assets/images/brutalist/Abstract 16.png',
    'assets/images/brutalist/Abstract 17.png',
    'assets/images/brutalist/Abstract 18.png',
    'assets/images/brutalist/Abstract 19.png',
    'assets/images/brutalist/Abstract 20.png',
    'assets/images/brutalist/Abstract 21.png',
    'assets/images/brutalist/Abstract 22.png',
    'assets/images/brutalist/Abstract 23.png',
    'assets/images/brutalist/Abstract 24.png',
    'assets/images/brutalist/Abstract 25.png',
    'assets/images/brutalist/Abstract 26.png',
    'assets/images/brutalist/Abstract 27.png',
    'assets/images/brutalist/Abstract 28.png',
    'assets/images/brutalist/Abstract 29.png',
    'assets/images/brutalist/Abstract 30.png',
    'assets/images/brutalist/Abstract 31.png',
    'assets/images/brutalist/Abstract 32.png',
    'assets/images/brutalist/Abstract 33.png',
    'assets/images/brutalist/Abstract 34.png',
    'assets/images/brutalist/Abstract 35.png',
    'assets/images/brutalist/Abstract 36.png',
    'assets/images/brutalist/Abstract 37.png',
    'assets/images/brutalist/Abstract 38.png',
    'assets/images/brutalist/Abstract 39.png',
    'assets/images/brutalist/Abstract 40.png',
    'assets/images/brutalist/Abstract 41.png',
    'assets/images/brutalist/Abstract 42.png',
    'assets/images/brutalist/Abstract 43.png',
    'assets/images/brutalist/Abstract 44.png',
    'assets/images/brutalist/Abstract 45.png',
    'assets/images/brutalist/Abstract 46.png',
    'assets/images/brutalist/Abstract 47.png',
    'assets/images/brutalist/Abstract 48.png',
    'assets/images/brutalist/Abstract 49.png',
    'assets/images/brutalist/Abstract 50.png',
    'assets/images/brutalist/Abstract 51.png',
    'assets/images/brutalist/Abstract 52.png',
    'assets/images/brutalist/Abstract 53.png',
    'assets/images/brutalist/Abstract 54.png',
    'assets/images/brutalist/Abstract 55.png',
    'assets/images/brutalist/Abstract 56.png',
    'assets/images/brutalist/Abstract 57.png',
    'assets/images/brutalist/Abstract 58.png',
    'assets/images/brutalist/Abstract 59.png',
    'assets/images/brutalist/Abstract 60.png',
    'assets/images/brutalist/Abstract 61.png',
    'assets/images/brutalist/Abstract 62.png',
    'assets/images/brutalist/Abstract 63.png',
    'assets/images/brutalist/Abstract 64.png',
    'assets/images/brutalist/Abstract 65.png',
    'assets/images/brutalist/Abstract 66.png',
    'assets/images/brutalist/Abstract 67.png',
    'assets/images/brutalist/Abstract 68.png',
    'assets/images/brutalist/Abstract 69.png',
    'assets/images/brutalist/Abstract 70.png',
    'assets/images/brutalist/Abstract 71.png',
    'assets/images/brutalist/Abstract 72.png',
    'assets/images/brutalist/Abstract 73.png',
    'assets/images/brutalist/Abstract 74.png',
    'assets/images/brutalist/Abstract 75.png',
    'assets/images/brutalist/Abstract 76.png',
    'assets/images/brutalist/Abstract 77.png',
    'assets/images/brutalist/Abstract 78.png',
    'assets/images/brutalist/Abstract 79.png',
    'assets/images/brutalist/Abstract 80.png',
    'assets/images/brutalist/Abstract 81.png',
    'assets/images/brutalist/Abstract 82.png',
    'assets/images/brutalist/Abstract 83.png',
    'assets/images/brutalist/Abstract 84.png',
    'assets/images/brutalist/Abstract 85.png',
    'assets/images/brutalist/Abstract 86.png',
    'assets/images/brutalist/Abstract 87.png',
    'assets/images/brutalist/Abstract 88.png',
    'assets/images/brutalist/Abstract 89.png',
    'assets/images/brutalist/Abstract 90.png',
    'assets/images/brutalist/Abstract 91.png',
    'assets/images/brutalist/Abstract 92.png',
    'assets/images/brutalist/Abstract 93.png',
    'assets/images/brutalist/Abstract 94.png',
    'assets/images/brutalist/Abstract 95.png',
    'assets/images/brutalist/Abstract 96.png',
    'assets/images/brutalist/Abstract 97.png',
    'assets/images/brutalist/Abstract 98.png',
    'assets/images/brutalist/Abstract 99.png',
    'assets/images/brutalist/Abstract 100.png',
    'assets/images/brutalist/Abstract 101.png',
    'assets/images/brutalist/Abstract 102.png',
    'assets/images/brutalist/Abstract 103.png',
    'assets/images/brutalist/Abstract 104.png',
    'assets/images/brutalist/Abstract 105.png',
    'assets/images/brutalist/Abstract 106.png',
    'assets/images/brutalist/Abstract 107.png',
    'assets/images/brutalist/Abstract 108.png',
    'assets/images/brutalist/Abstract 109.png',
    'assets/images/brutalist/Abstract 110.png',
    'assets/images/brutalist/Abstract 111.png',
    'assets/images/brutalist/Abstract 112.png',
    'assets/images/brutalist/Abstract 113.png',
    'assets/images/brutalist/Abstract 114.png',
    'assets/images/brutalist/Abstract 115.png',
    'assets/images/brutalist/Abstract 116.png',
    'assets/images/brutalist/Abstract 117.png',
    'assets/images/brutalist/Abstract 118.png',
    'assets/images/brutalist/Abstract 119.png',
    'assets/images/brutalist/Abstract 120.png',
    'assets/images/brutalist/Abstract 121.png',
    'assets/images/brutalist/Abstract 122.png',
    'assets/images/brutalist/Abstract 123.png',
    'assets/images/brutalist/Abstract 124.png',
    'assets/images/brutalist/Abstract 125.png',
    'assets/images/brutalist/Abstract 126.png',
    'assets/images/brutalist/Abstract 127.png',
    'assets/images/brutalist/Abstract 128.png',
    'assets/images/brutalist/Abstract 129.png',
    'assets/images/brutalist/Abstract 130.png',
    'assets/images/brutalist/Abstract 131.png',
    'assets/images/brutalist/Abstract 132.png',
    'assets/images/brutalist/Abstract 133.png',
    'assets/images/brutalist/Abstract 134.png',
    'assets/images/brutalist/Abstract 135.png',
    'assets/images/brutalist/Abstract 136.png',
    'assets/images/brutalist/Abstract 137.png',
    'assets/images/brutalist/Abstract 138.png',
    'assets/images/brutalist/Abstract 139.png',
    'assets/images/brutalist/Abstract 140.png',
    'assets/images/brutalist/Abstract 141.png',
    'assets/images/brutalist/Abstract 142.png',
    'assets/images/brutalist/Abstract 143.png',
    'assets/images/brutalist/Abstract 144.png',
    'assets/images/brutalist/Abstract 145.png',
    'assets/images/brutalist/Abstract 146.png',
    'assets/images/brutalist/Abstract 147.png',
    'assets/images/brutalist/Abstract 148.png',
    'assets/images/brutalist/Abstract 149.png',
    'assets/images/brutalist/Abstract 150.png',
    'assets/images/brutalist/Abstract 151.png',
    'assets/images/brutalist/Abstract 152.png',
    'assets/images/brutalist/Abstract 153.png',
    'assets/images/brutalist/Abstract 154.png',
    'assets/images/brutalist/Abstract 155.png',
    'assets/images/brutalist/Abstract 156.png',
    'assets/images/brutalist/Abstract 157.png',
    'assets/images/brutalist/Abstract 158.png',
    'assets/images/brutalist/Abstract 159.png',
    'assets/images/brutalist/Abstract 160.png',
    'assets/images/brutalist/Abstract 161.png',
    'assets/images/brutalist/Abstract 162.png',
    'assets/images/brutalist/Abstract 163.png',
    'assets/images/brutalist/Abstract 164.png',
    'assets/images/brutalist/Abstract 165.png',
    'assets/images/brutalist/Abstract 166.png',
    'assets/images/brutalist/Abstract 167.png',
    'assets/images/brutalist/Abstract 168.png',
    'assets/images/brutalist/Abstract 169.png',
    'assets/images/brutalist/Abstract 170.png',
    'assets/images/brutalist/Abstract 171.png',
    'assets/images/brutalist/Abstract 172.png',
    'assets/images/brutalist/Abstract 173.png',
    'assets/images/brutalist/Abstract 174.png',
    'assets/images/brutalist/Abstract 175.png',
    'assets/images/brutalist/Abstract 176.png',
    'assets/images/brutalist/Abstract 177.png',
    'assets/images/brutalist/Abstract 178.png',
    'assets/images/brutalist/Abstract 179.png',
    'assets/images/brutalist/Abstract 180.png',
    'assets/images/brutalist/Abstract 181.png',
    'assets/images/brutalist/Abstract 182.png',
    'assets/images/brutalist/Abstract 183.png',
    'assets/images/brutalist/Abstract 184.png',
    'assets/images/brutalist/Abstract 185.png',
    'assets/images/brutalist/Abstract 186.png',
    'assets/images/brutalist/Abstract 187.png',
    'assets/images/brutalist/Abstract 188.png',
    'assets/images/brutalist/Abstract 189.png',
    'assets/images/brutalist/Abstract 190.png',
    'assets/images/brutalist/Abstract 191.png',
    'assets/images/brutalist/Abstract 192.png',
    'assets/images/brutalist/Abstract 193.png',
    'assets/images/brutalist/Abstract 194.png',
    'assets/images/brutalist/Abstract 195.png',
    'assets/images/brutalist/Abstract 196.png',
    'assets/images/brutalist/Abstract 197.png',
    'assets/images/brutalist/Abstract 198.png',
    'assets/images/brutalist/Abstract 199.png',
    'assets/images/brutalist/Abstract 200.png',
    'assets/images/brutalist/Abstract 201.png',
    'assets/images/brutalist/Abstract 202.png',
    'assets/images/brutalist/Abstract 203.png',
    'assets/images/brutalist/Abstract 204.png',
    'assets/images/brutalist/Abstract 205.png',
    'assets/images/brutalist/Abstract 206.png',
    'assets/images/brutalist/Abstract 207.png',
    'assets/images/brutalist/Abstract 208.png',
    'assets/images/brutalist/Abstract 209.png',
    'assets/images/brutalist/Abstract 210.png',
    'assets/images/brutalist/Abstract 211.png',
    'assets/images/brutalist/Abstract 212.png',
    'assets/images/brutalist/Abstract 213.png',
    'assets/images/brutalist/Abstract 214.png',
    'assets/images/brutalist/Abstract 215.png',
    'assets/images/brutalist/Abstract 216.png',
    'assets/images/brutalist/Abstract 217.png',
    'assets/images/brutalist/Abstract 218.png',
    'assets/images/brutalist/Abstract 219.png',
    'assets/images/brutalist/Abstract 220.png',
    'assets/images/brutalist/Abstract 221.png',
    'assets/images/brutalist/Abstract 222.png',
    'assets/images/brutalist/Abstract 223.png',
    'assets/images/brutalist/Abstract 224.png',
    'assets/images/brutalist/Abstract 225.png',
    'assets/images/brutalist/Abstract 226.png',
    'assets/images/brutalist/Abstract 227.png',
    'assets/images/brutalist/Abstract 228.png',
    'assets/images/brutalist/Abstract 229.png',
    'assets/images/brutalist/Abstract 230.png',
    'assets/images/brutalist/Abstract 231.png',
    'assets/images/brutalist/Abstract 232.png',
    'assets/images/brutalist/Abstract 233.png',
    'assets/images/brutalist/Abstract 234.png',
    'assets/images/brutalist/Abstract 235.png',
    'assets/images/brutalist/Abstract 236.png',
    'assets/images/brutalist/Abstract 237.png',
    'assets/images/brutalist/Abstract 238.png',
    'assets/images/brutalist/Abstract 239.png',
    'assets/images/brutalist/Abstract 240.png',
    'assets/images/brutalist/Abstract 241.png',
    'assets/images/brutalist/Abstract 242.png',
    'assets/images/brutalist/Abstract 243.png',
    'assets/images/brutalist/Abstract 244.png',
    'assets/images/brutalist/Abstract 245.png',
    'assets/images/brutalist/Abstract 246.png',
    'assets/images/brutalist/Abstract 247.png',
    'assets/images/brutalist/Abstract 248.png',
    'assets/images/brutalist/Abstract 249.png',
    'assets/images/brutalist/Abstract 250.png',
    'assets/images/brutalist/Abstract 251.png',
    'assets/images/brutalist/Abstract 252.png',
    'assets/images/brutalist/Abstract 253.png',
    'assets/images/brutalist/Abstract 254.png',
    'assets/images/brutalist/Abstract 255.png',
    'assets/images/brutalist/Abstract 256.png',
    'assets/images/brutalist/Abstract 257.png',
    'assets/images/brutalist/Abstract 258.png',
    'assets/images/brutalist/Abstract 259.png',
    'assets/images/brutalist/Abstract 260.png',
    'assets/images/brutalist/Abstract 261.png',
    'assets/images/brutalist/Abstract 262.png',
  ];

  static const _bauhausImages = [
    'assets/images/brutalist/Bauhaus 1.png',
    'assets/images/brutalist/Bauhaus 2.png',
    'assets/images/brutalist/Bauhaus 3.png',
    'assets/images/brutalist/Bauhaus 4.png',
    'assets/images/brutalist/Bauhaus 5.png',
    'assets/images/brutalist/Bauhaus 6.png',
    'assets/images/brutalist/Bauhaus 7.png',
    'assets/images/brutalist/Bauhaus 8.png',
    'assets/images/brutalist/Bauhaus 9.png',
    'assets/images/brutalist/Bauhaus 10.png',
    'assets/images/brutalist/Bauhaus 11.png',
    'assets/images/brutalist/Bauhaus 12.png',
    'assets/images/brutalist/Bauhaus 13.png',
    'assets/images/brutalist/Bauhaus 14.png',
    'assets/images/brutalist/Bauhaus 15.png',
    'assets/images/brutalist/Bauhaus 16.png',
    'assets/images/brutalist/Bauhaus 17.png',
    'assets/images/brutalist/Bauhaus 18.png',
    'assets/images/brutalist/Bauhaus 19.png',
    'assets/images/brutalist/Bauhaus 20.png',
    'assets/images/brutalist/Bauhaus 21.png',
    'assets/images/brutalist/Bauhaus 22.png',
    'assets/images/brutalist/Bauhaus 23.png',
    'assets/images/brutalist/Bauhaus 24.png',
    'assets/images/brutalist/Bauhaus 25.png',
    'assets/images/brutalist/Bauhaus 26.png',
    'assets/images/brutalist/Bauhaus 27.png',
    'assets/images/brutalist/Bauhaus 28.png',
    'assets/images/brutalist/Bauhaus 29.png',
    'assets/images/brutalist/Bauhaus 30.png',
    'assets/images/brutalist/Bauhaus 31.png',
    'assets/images/brutalist/Bauhaus 32.png',
    'assets/images/brutalist/Bauhaus 33.png',
    'assets/images/brutalist/Bauhaus 34.png',
    'assets/images/brutalist/Bauhaus 35.png',
    'assets/images/brutalist/Bauhaus 36.png',
    'assets/images/brutalist/Bauhaus 37.png',
    'assets/images/brutalist/Bauhaus 38.png',
    'assets/images/brutalist/Bauhaus 39.png',
    'assets/images/brutalist/Bauhaus 40.png',
  ];

  static const _brutalismImages = [
    'assets/images/brutalist/Brutalism 1.png',
    'assets/images/brutalist/Brutalism 2.png',
    'assets/images/brutalist/Brutalism 3.png',
    'assets/images/brutalist/Brutalism 4.png',
    'assets/images/brutalist/Brutalism 5.png',
    'assets/images/brutalist/Brutalism 6.png',
    'assets/images/brutalist/Brutalism 7.png',
    'assets/images/brutalist/Brutalism 8.png',
    'assets/images/brutalist/Brutalism 9.png',
    'assets/images/brutalist/Brutalism 10.png',
    'assets/images/brutalist/Brutalism 11.png',
    'assets/images/brutalist/Brutalism 12.png',
    'assets/images/brutalist/Brutalism 13.png',
    'assets/images/brutalist/Brutalism 14.png',
    'assets/images/brutalist/Brutalism 15.png',
    'assets/images/brutalist/Brutalism 16.png',
    'assets/images/brutalist/Brutalism 17.png',
    'assets/images/brutalist/Brutalism 18.png',
    'assets/images/brutalist/Brutalism 19.png',
    'assets/images/brutalist/Brutalism 20.png',
    'assets/images/brutalist/Brutalism 21.png',
    'assets/images/brutalist/Brutalism 22.png',
    'assets/images/brutalist/Brutalism 23.png',
    'assets/images/brutalist/Brutalism 24.png',
    'assets/images/brutalist/Brutalism 25.png',
    'assets/images/brutalist/Brutalism 26.png',
    'assets/images/brutalist/Brutalism 27.png',
    'assets/images/brutalist/Brutalism 28.png',
    'assets/images/brutalist/Brutalism 29.png',
    'assets/images/brutalist/Brutalism 30.png',
    'assets/images/brutalist/Brutalism 31.png',
    'assets/images/brutalist/Brutalism 32.png',
    'assets/images/brutalist/Brutalism 33.png',
    'assets/images/brutalist/Brutalism 34.png',
    'assets/images/brutalist/Brutalism 35.png',
    'assets/images/brutalist/Brutalism 36.png',
    'assets/images/brutalist/Brutalism 37.png',
    'assets/images/brutalist/Brutalism 38.png',
    'assets/images/brutalist/Brutalism 39.png',
    'assets/images/brutalist/Brutalism 40.png',
    'assets/images/brutalist/Brutalism 41.png',
    'assets/images/brutalist/Brutalism 42.png',
    'assets/images/brutalist/Brutalism 43.png',
    'assets/images/brutalist/Brutalism 44.png',
    'assets/images/brutalist/Brutalism 45.png',
    'assets/images/brutalist/Brutalism 46.png',
    'assets/images/brutalist/Brutalism 47.png',
    'assets/images/brutalist/Brutalism 48.png',
    'assets/images/brutalist/Brutalism 49.png',
    'assets/images/brutalist/Brutalism 50.png',
    'assets/images/brutalist/Brutalism 51.png',
    'assets/images/brutalist/Brutalism 52.png',
    'assets/images/brutalist/Brutalism 53.png',
    'assets/images/brutalist/Brutalism 54.png',
    'assets/images/brutalist/Brutalism 55.png',
    'assets/images/brutalist/Brutalism 56.png',
    'assets/images/brutalist/Brutalism 57.png',
    'assets/images/brutalist/Brutalism 58.png',
    'assets/images/brutalist/Brutalism 59.png',
    'assets/images/brutalist/Brutalism 60.png',
    'assets/images/brutalist/Brutalism 61.png',
    'assets/images/brutalist/Brutalism 62.png',
    'assets/images/brutalist/Brutalism 63.png',
    'assets/images/brutalist/Brutalism 64.png',
    'assets/images/brutalist/Brutalism 65.png',
    'assets/images/brutalist/Brutalism 66.png',
    'assets/images/brutalist/Brutalism 67.png',
    'assets/images/brutalist/Brutalism 68.png',
    'assets/images/brutalist/Brutalism 69.png',
    'assets/images/brutalist/Brutalism 70.png',
    'assets/images/brutalist/Brutalism 71.png',
    'assets/images/brutalist/Brutalism 72.png',
    'assets/images/brutalist/Brutalism 73.png',
    'assets/images/brutalist/Brutalism 74.png',
    'assets/images/brutalist/Brutalism 75.png',
    'assets/images/brutalist/Brutalism 76.png',
    'assets/images/brutalist/Brutalism 77.png',
    'assets/images/brutalist/Brutalism 78.png',
    'assets/images/brutalist/Brutalism 79.png',
    'assets/images/brutalist/Brutalism 80.png',
    'assets/images/brutalist/Brutalism 81.png',
    'assets/images/brutalist/Brutalism 82.png',
    'assets/images/brutalist/Brutalism 83.png',
    'assets/images/brutalist/Brutalism 84.png',
    'assets/images/brutalist/Brutalism 85.png',
    'assets/images/brutalist/Brutalism 86.png',
    'assets/images/brutalist/Brutalism 87.png',
    'assets/images/brutalist/Brutalism 88.png',
    'assets/images/brutalist/Brutalism 89.png',
    'assets/images/brutalist/Brutalism 90.png',
    'assets/images/brutalist/Brutalism 91.png',
    'assets/images/brutalist/Brutalism 92.png',
    'assets/images/brutalist/Brutalism 93.png',
    'assets/images/brutalist/Brutalism 94.png',
    'assets/images/brutalist/Brutalism 95.png',
    'assets/images/brutalist/Brutalism 96.png',
    'assets/images/brutalist/Brutalism 97.png',
    'assets/images/brutalist/Brutalism 98.png',
    'assets/images/brutalist/Brutalism 99.png',
    'assets/images/brutalist/Brutalism 100.png',
    'assets/images/brutalist/Brutalism 101.png',
    'assets/images/brutalist/Brutalism 102.png',
    'assets/images/brutalist/Brutalism 103.png',
    'assets/images/brutalist/Brutalism 104.png',
    'assets/images/brutalist/Brutalism 105.png',
    'assets/images/brutalist/Brutalism 106.png',
    'assets/images/brutalist/Brutalism 107.png',
    'assets/images/brutalist/Brutalism 108.png',
    'assets/images/brutalist/Brutalism 109.png',
    'assets/images/brutalist/Brutalism 110.png',
    'assets/images/brutalist/Brutalism 111.png',
    'assets/images/brutalist/Brutalism 112.png',
    'assets/images/brutalist/Brutalism 113.png',
    'assets/images/brutalist/Brutalism 114.png',
    'assets/images/brutalist/Brutalism 115.png',
    'assets/images/brutalist/Brutalism 116.png',
    'assets/images/brutalist/Brutalism 117.png',
    'assets/images/brutalist/Brutalism 118.png',
  ];

  static const _allImages = _abstractImages + _bauhausImages + _brutalismImages;

  static const _colorPairs = [
    _ColorPair(tint: Color(0xFFFFA617), background: Color(0xFF0056B3)),
    _ColorPair(tint: Color(0xFF59C9DF), background: Color(0xFFDC2626)),
    _ColorPair(tint: Color(0xFFC678FF), background: Color(0xFF16A34A)),
    _ColorPair(tint: Color(0xFFFF79D7), background: Color(0xFF047857)),
    _ColorPair(tint: Color(0xFFFFD800), background: Color(0xFF4C1D95)),
    _ColorPair(tint: Color(0xFF84E600), background: Color(0xFFC026D3)),
  ];

  @override
  Widget build(BuildContext context) {
    final hash = _avatarHashCode(id);
    final imageIndex = hash % _allImages.length;
    final colorIndex = hash % _colorPairs.length;

    final imagePath = _allImages[imageIndex];
    final colorPair = _colorPairs[colorIndex];
    final tintColor = monochrome ? const Color(0xFF999999) : colorPair.tint;
    final backgroundColor =
        monochrome ? const Color(0xFFF0F0F0) : colorPair.background;

    final borderRadius = square ? 0.0 : size / 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: backgroundColor,
      ),
      child: Center(
        child: Image.asset(
          imagePath,
          width: size * 0.8,
          height: size * 0.8,
          color: tintColor,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person,
            size: size * 0.6,
            color: tintColor,
          ),
        ),
      ),
    );
  }
}

class _ColorPair {
  final Color tint;
  final Color background;

  const _ColorPair({required this.tint, required this.background});
}

/// AvatarGradient - Uses gradient images for avatar
class AvatarGradient extends StatelessWidget {
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  const AvatarGradient({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });

  static const _gradientImages = [
    'assets/images/gradients/01.png',
    'assets/images/gradients/02.png',
    'assets/images/gradients/03.png',
    'assets/images/gradients/04.png',
    'assets/images/gradients/05.png',
    'assets/images/gradients/06.png',
    'assets/images/gradients/07.png',
    'assets/images/gradients/08.png',
    'assets/images/gradients/09.png',
    'assets/images/gradients/10.png',
    'assets/images/gradients/11.png',
    'assets/images/gradients/12.png',
    'assets/images/gradients/13.png',
    'assets/images/gradients/14.png',
    'assets/images/gradients/15.png',
    'assets/images/gradients/16.png',
    'assets/images/gradients/17.png',
    'assets/images/gradients/18.png',
    'assets/images/gradients/19.png',
    'assets/images/gradients/20.png',
    'assets/images/gradients/21.png',
    'assets/images/gradients/22.png',
    'assets/images/gradients/23.png',
    'assets/images/gradients/24.png',
    'assets/images/gradients/25.png',
    'assets/images/gradients/26.png',
    'assets/images/gradients/27.png',
    'assets/images/gradients/28.png',
    'assets/images/gradients/29.png',
    'assets/images/gradients/30.png',
    'assets/images/gradients/31.png',
    'assets/images/gradients/32.png',
    'assets/images/gradients/33.png',
    'assets/images/gradients/34.png',
    'assets/images/gradients/35.png',
    'assets/images/gradients/36.png',
    'assets/images/gradients/37.png',
    'assets/images/gradients/38.png',
    'assets/images/gradients/39.png',
    'assets/images/gradients/40.png',
    'assets/images/gradients/41.png',
    'assets/images/gradients/42.png',
    'assets/images/gradients/43.png',
    'assets/images/gradients/44.png',
    'assets/images/gradients/45.png',
    'assets/images/gradients/46.png',
    'assets/images/gradients/47.png',
    'assets/images/gradients/48.png',
    'assets/images/gradients/49.png',
    'assets/images/gradients/50.png',
    'assets/images/gradients/51.png',
    'assets/images/gradients/52.png',
    'assets/images/gradients/53.png',
    'assets/images/gradients/54.png',
    'assets/images/gradients/55.png',
    'assets/images/gradients/56.png',
    'assets/images/gradients/57.png',
    'assets/images/gradients/58.png',
    'assets/images/gradients/59.png',
    'assets/images/gradients/60.png',
    'assets/images/gradients/61.png',
    'assets/images/gradients/62.png',
    'assets/images/gradients/63.png',
    'assets/images/gradients/64.png',
    'assets/images/gradients/65.png',
    'assets/images/gradients/66.png',
    'assets/images/gradients/67.png',
    'assets/images/gradients/68.png',
    'assets/images/gradients/69.png',
    'assets/images/gradients/70.png',
    'assets/images/gradients/71.png',
    'assets/images/gradients/72.png',
    'assets/images/gradients/73.png',
    'assets/images/gradients/74.png',
    'assets/images/gradients/75.png',
    'assets/images/gradients/76.png',
    'assets/images/gradients/77.png',
    'assets/images/gradients/78.png',
    'assets/images/gradients/79.png',
    'assets/images/gradients/80.png',
    'assets/images/gradients/81.png',
    'assets/images/gradients/82.png',
    'assets/images/gradients/83.png',
    'assets/images/gradients/84.png',
    'assets/images/gradients/85.png',
    'assets/images/gradients/86.png',
    'assets/images/gradients/87.png',
    'assets/images/gradients/88.png',
    'assets/images/gradients/89.png',
    'assets/images/gradients/90.png',
    'assets/images/gradients/91.png',
    'assets/images/gradients/92.png',
    'assets/images/gradients/93.png',
    'assets/images/gradients/94.png',
    'assets/images/gradients/95.png',
    'assets/images/gradients/96.png',
    'assets/images/gradients/97.png',
    'assets/images/gradients/98.png',
    'assets/images/gradients/99.png',
    'assets/images/gradients/100.png',
  ];

  @override
  Widget build(BuildContext context) {
    final hash = _avatarHashCode(id);
    final imageIndex = hash % _gradientImages.length;
    final imagePath = _gradientImages[imageIndex];

    final borderRadius = square ? 0.0 : size / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        color: monochrome ? const Color(0xFF808080) : null,
        colorBlendMode: monochrome ? BlendMode.saturation : BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

/// AvatarSkia - 8x8 pixel grid with generative colors
class AvatarSkia extends StatelessWidget {
  final String id;
  final double size;
  final bool square;
  final bool monochrome;

  static const _gridSize = 8;
  static const _elements = 64;
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

  const AvatarSkia({
    required this.id,
    this.size = 48,
    this.square = false,
    this.monochrome = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hash = _avatarHashCode(id);
    final palette = monochrome ? _grayscalePalette : _colorPalette;
    final cellSize = size / _gridSize;

    final borderRadius = square ? 0.0 : size / 2;

    return ClipRRect(
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
  final String id;
  final int hash;
  final List<String> palette;
  final bool monochrome;

  _PixelGridPainter({
    required this.id,
    required this.hash,
    required this.palette,
    required this.monochrome,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 8;

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final index = row * 8 + col;
        final colorHash = (hash + index) % palette.length;
        var colorStr = palette[colorHash];

        // Generate varied colors using golden angle
        if (!monochrome) {
          final hue = ((hash + index * 137.508) % 360).toInt();
          colorStr = 'hsl($hue, 45%, 65%)';
        }

        final paint = Paint()..color = _parseColor(colorStr);
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

  Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hex = colorStr.substring(1);
      return Color(int.parse(hex, radix: 16) | 0xFF000000);
    }

    // Parse HSL
    final match = RegExp(r'hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)')
        .firstMatch(colorStr);
    if (match != null) {
      final h = int.parse(match.group(1)!);
      final s = int.parse(match.group(2)!);
      final l = int.parse(match.group(3)!);
      return HSLColor.fromAHSL(1.0, h.toDouble(), s / 100, l / 100).toColor();
    }

    return Colors.grey;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Flavor icon overlay widget for AI assistant avatars
class FlavorIconOverlay extends StatelessWidget {
  final FlavorIcon flavor;
  final double avatarSize;
  final bool showBackground;

  const FlavorIconOverlay({
    required this.flavor,
    required this.avatarSize,
    this.showBackground = true,
    super.key,
  });

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
  final String id;
  final double size;
  final bool square;
  final bool monochrome;
  final FlavorIcon? flavor;
  final String? imageUrl;
  final String? thumbhash;
  final AvatarStyle style;
  final bool showFlavorIcon;

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
    final imageElement = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Colors.grey[600],
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
