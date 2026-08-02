import 'package:flutter/material.dart';

import 'avatar_palette.dart';

/// Base avatar widget
abstract class BaseAvatar extends StatelessWidget {

  const BaseAvatar({
    required this.id, super.key,
    this.size = 48,
  });
  final String id;
  final double size;

  /// Generate a consistent identity color from the ID.
  ///
  /// Pass the ambient [brightness] so the same session keeps a
  /// recognisable — but theme-appropriate — color in light and dark.
  Color generateColor(String id, [Brightness brightness = Brightness.light]) {
    return avatarBackgroundColor(id, brightness);
  }

  /// Generate a secondary color
  Color generateSecondaryColor(
    String id, [
    Brightness brightness = Brightness.light,
  ]) {
    return avatarAccentColor(id, brightness);
  }

  /// Readable ink for initials drawn on [background].
  Color generateOnColor(Color background) => avatarForegroundColor(background);

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
