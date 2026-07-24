import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Uppercase-ish section label above an artifact form field.
class ArtifactSectionLabel extends StatelessWidget {
  const ArtifactSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontSize: AppFontSize.sm,
      ),
    );
  }
}

/// Filled, rounded input decoration shared by the artifact create and edit
/// forms. Both screens previously inlined this ~25-line block twice each.
InputDecoration artifactFieldDecoration(
  BuildContext context, {
  required String hintText,
  bool alignLabelWithHint = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(
      color: cs.outlineVariant.withValues(alpha: 0.5),
    ),
  );
  return InputDecoration(
    hintText: hintText,
    border: border,
    enabledBorder: border,
    filled: true,
    fillColor: cs.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    alignLabelWithHint: alignLabelWithHint,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    ),
  );
}
