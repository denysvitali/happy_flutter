import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_badge.dart';

/// A chip widget that displays a file path with monospace font
class PathChip extends StatelessWidget {
  /// Creates a path chip
  const PathChip({required this.path, super.key});

  /// The path string to display
  final String path;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: path,
      leading: const Icon(Icons.folder_outlined),
      outlined: true,
      monospace: true,
    );
  }
}
