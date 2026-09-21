import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Small pill label used to tag profile rows and preset suggestions
/// (e.g. "Built-in", "Custom", "Suggested").
class ProfilePill extends StatelessWidget {
  const ProfilePill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.xxs,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
