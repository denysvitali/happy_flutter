import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Tiny status label shown below user bubbles for optimistic messages.
class SendStatusIndicator extends StatelessWidget {
  const SendStatusIndicator({
    required this.status,
    super.key,
    this.onRetry,
  });

  final String status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xxs,
      height: 1.2,
    );

    switch (status) {
      case 'sending':
        return Padding(
          padding: const EdgeInsets.only(
            top: 3,
            right: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: cs.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'Sending',
                style: style?.copyWith(
                  color: cs.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'failed':
        return Padding(
          padding: const EdgeInsets.only(
            top: 3,
            right: 2,
          ),
          child: InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 10,
                  color: cs.error.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 3),
                Text(
                  'Failed to send',
                  style: style?.copyWith(
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.refresh,
                    size: 10,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        );
      default:
        // 'sent' or unknown — no indicator.
        return const SizedBox.shrink();
    }
  }
}
