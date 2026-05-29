import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Centered error placeholder with an icon, message, and optional retry.
///
/// Consolidates the hand-rolled error containers used across screens.
/// The icon uses [ColorScheme.error]; the message uses
/// [TextTheme.bodyMedium]. When [onRetry] is provided, a retry button is
/// shown beneath the message.
class AppErrorState extends StatelessWidget {
  /// Creates an error-state placeholder.
  const AppErrorState({
    required this.message,
    super.key,
    this.onRetry,
    this.icon,
    this.retryLabel,
  });

  /// The error message to display.
  final String message;

  /// Optional retry callback. When non-null, a retry button is shown.
  final VoidCallback? onRetry;

  /// The icon shown above the message.
  ///
  /// Defaults to [Icons.warning_amber_rounded] when null.
  final IconData? icon;

  /// Optional label for the retry button. Defaults to "Retry".
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.warning_amber_rounded,
                size: AppSpacing.xxl * 2,
                color: cs.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel ?? 'Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
