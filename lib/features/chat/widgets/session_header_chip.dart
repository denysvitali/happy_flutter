import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_badge.dart';

/// A small chip used in the session header to display status or machine info
class SessionHeaderChip extends StatelessWidget {
  /// Creates a [SessionHeaderChip].
  const SessionHeaderChip({
    required this.text,
    this.leading,
    this.color,
    this.tooltip,
    super.key,
  });

  /// Chip label.
  final String text;

  /// Optional widget before the label (e.g. a status dot).
  final Widget? leading;

  /// Optional categorical hue; neutral when null.
  final Color? color;

  /// Tooltip; defaults to [text].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? text,
      child: AppBadge(label: text, leading: leading, color: color),
    );
  }
}
