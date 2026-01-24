import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Base avatar widget
abstract class BaseAvatar extends StatelessWidget {
  final String id;
  final double size;

  const BaseAvatar({
    super.key,
    required this.id,
    this.size = 48,
  });

  /// Generate a consistent color from the ID
  Color generateColor(String id) {
    final hash = id.codeUnits.fold(0, (acc, char) => acc + char);
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.6, 0.9).toColor();
  }

  /// Generate a secondary color
  Color generateSecondaryColor(String id) {
    final hash = id.codeUnits.fold(0, (acc, char) => acc + char);
    final hue = ((hash + 120) % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.85).toColor();
  }

  /// Generate initials from ID
  String generateInitials(String id) {
    final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleanId.isEmpty) return '?';
    if (cleanId.length >= 2) {
      return '${cleanId[0]}${cleanId[1]}'.toUpperCase();
    }
    return cleanId.toUpperCase();
  }
}
