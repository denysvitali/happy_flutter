import 'package:flutter/material.dart';

/// Canonical mapping from file extension to a display color and Material icon.
///
/// Merges the previously duplicated extension maps in the Read/LS/Glob tool
/// views into a single source of truth. Extensions may be passed with or
/// without a leading dot and in any case; they are normalized internally.
class FileTypeColors {
  const FileTypeColors._();

  /// Fallback color for unknown extensions.
  static const Color defaultColor = Color(0xFF8B949E);

  /// Fallback icon for unknown extensions.
  static const IconData defaultIcon = Icons.insert_drive_file_outlined;

  /// Returns the display color for [ext] (dot/case-insensitive).
  static Color colorForExtension(String ext) =>
      _colors[_normalize(ext)] ?? defaultColor;

  /// Returns the Material icon for [ext] (dot/case-insensitive).
  static IconData iconForExtension(String ext) =>
      _icons[_normalize(ext)] ?? defaultIcon;

  /// Lowercases [ext] and strips a single leading dot.
  static String _normalize(String ext) {
    final lower = ext.toLowerCase();
    return lower.startsWith('.') ? lower.substring(1) : lower;
  }

  static const Color _jsYellow = Color(0xFFF7DF1E);
  static const Color _tsBlue = Color(0xFF3178C6);
  static const Color _green = Color(0xFF85E89D);
  static const Color _shellGreen = Color(0xFF3FB950);
  static const Color _red = Color(0xFFEF5350);
  static const Color _cssBlue = Color(0xFF42A5F5);
  static const Color _imagePink = Color(0xFFEC407A);

  static const Map<String, Color> _colors = <String, Color>{
    // Dart — canonical 0xFF54C5F8 (resolves read_view vs ls_view 0xFF42A5F5).
    'dart': Color(0xFF54C5F8),
    'js': _jsYellow,
    'jsx': _jsYellow,
    'ts': _tsBlue,
    'tsx': _tsBlue,
    'py': Color(0xFF3572A5),
    'go': Color(0xFF00ADD8),
    'rs': Color(0xFFDEA584),
    'swift': _red,
    'kt': Color(0xFF7E57C2),
    'kts': Color(0xFF7E57C2),
    'md': Color(0xFF8B949E),
    'markdown': Color(0xFF8B949E),
    'json': _green,
    'yaml': _green,
    'yml': _green,
    'sh': _shellGreen,
    'bash': _shellGreen,
    'zsh': _shellGreen,
    'html': _red,
    'htm': _red,
    'css': _cssBlue,
    'scss': _cssBlue,
    'less': _cssBlue,
    'png': _imagePink,
    'jpg': _imagePink,
    'jpeg': _imagePink,
    'gif': _imagePink,
    'svg': _imagePink,
    'webp': _imagePink,
  };

  static const Map<String, IconData> _icons = <String, IconData>{
    'dart': Icons.code,
    'js': Icons.code,
    'jsx': Icons.code,
    'ts': Icons.code,
    'tsx': Icons.code,
    'py': Icons.code,
    'rb': Icons.code,
    'go': Icons.code,
    'rs': Icons.code,
    'java': Icons.code,
    'kt': Icons.code,
    'kts': Icons.code,
    'swift': Icons.code,
    'cpp': Icons.code,
    'c': Icons.code,
    'h': Icons.code,
    'sh': Icons.terminal,
    'bash': Icons.terminal,
    'zsh': Icons.terminal,
    'json': Icons.data_object,
    'yaml': Icons.data_object,
    'yml': Icons.data_object,
    'toml': Icons.data_object,
    'xml': Icons.data_object,
    'md': Icons.article_outlined,
    'markdown': Icons.article_outlined,
    'txt': Icons.article_outlined,
    'rst': Icons.article_outlined,
    'html': Icons.web,
    'htm': Icons.web,
    'css': Icons.web,
    'scss': Icons.web,
    'less': Icons.web,
    'png': Icons.image_outlined,
    'jpg': Icons.image_outlined,
    'jpeg': Icons.image_outlined,
    'gif': Icons.image_outlined,
    'svg': Icons.image_outlined,
    'webp': Icons.image_outlined,
  };
}
