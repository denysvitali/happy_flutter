import 'package:flutter/material.dart';

/// Small all-caps section label used by tool views
/// (e.g. "COMMAND", "OUTPUT", "CONTENT").
class SectionLabel extends StatelessWidget {
  /// Creates a [SectionLabel].
  const SectionLabel({required this.label, super.key});

  /// The label text to display (typically uppercase).
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 0.8,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier'],
      ),
    );
  }
}
