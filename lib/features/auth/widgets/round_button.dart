import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/theme/app_tokens.dart';

/// Custom round button widget similar to happy project's
/// RoundButton.
class RoundButton extends StatelessWidget {
  const RoundButton({
    required this.title,
    super.key,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = AppTouchTarget.comfortable + 4,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? theme.colorScheme.primary
              : Colors.transparent,
          foregroundColor: isPrimary
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isPrimary
              ? null
              : BorderSide(
                  color: theme.colorScheme.outline,
                ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: isLoading
            ? AppLoadingIndicator(
                size: AppSpacing.xl - AppSpacing.sm,
                strokeWidth: 2,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              )
            : Text(
                title,
                style: TextStyle(
                  fontSize: isPrimary ? 18 : 16,
                  fontWeight: isPrimary
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}
