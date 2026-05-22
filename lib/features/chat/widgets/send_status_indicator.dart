import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Tiny status label shown below user bubbles for optimistic messages.
class SendStatusIndicator extends StatelessWidget {
  const SendStatusIndicator({required this.status, super.key, this.onRetry});

  final String status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xxs,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    switch (status) {
      case 'sending':
        return _StatusLabel(
          label: 'Sending',
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          indicator: SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        );
      case 'pending':
        return _StatusLabel(
          label: 'Retry queued',
          color: cs.secondary,
          indicator: Icon(
            Icons.schedule_rounded,
            size: 10,
            color: cs.secondary,
          ),
        );
      case 'sent':
        return _StatusLabel(
          label: 'Delivered',
          color: cs.primary.withValues(alpha: 0.85),
          indicator: Icon(
            Icons.check_rounded,
            size: 10,
            color: cs.primary.withValues(alpha: 0.85),
          ),
        );
      case 'failed':
        // TODO(l10n): localize retry button semantic label
        return Semantics(
          button: onRetry != null,
          label: onRetry != null
              ? 'Message not delivered — tap to retry'
              : 'Message not delivered',
          child: Padding(
            padding: const EdgeInsets.only(top: 3, right: 2),
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
                    'Not delivered',
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
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.label,
    required this.color,
    required this.indicator,
  });

  final String label;
  final Color color;
  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xxs,
      height: 1.2,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 3),
          Text(label, style: style),
        ],
      ),
    );
  }
}
