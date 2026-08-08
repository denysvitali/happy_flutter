import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Tiny status label shown below user bubbles for optimistic messages.
///
/// Wraps each state in a [Semantics] node with [liveRegion] so screen readers
/// announce transitions automatically.  When the [status] prop changes the
/// widget also calls [SemanticsService.sendAnnouncement] so assistive
/// technology receives an explicit live-region notification.
class SendStatusIndicator extends StatefulWidget {
  const SendStatusIndicator({
    required this.status,
    super.key,
    this.slow = false,
    this.onRetry,
  });

  final String status;

  /// True when a `'sent'` message got there only after the client's send
  /// deadline expired and the outbox retry found it already persisted.
  /// A slow success is still a success — say so instead of leaving the
  /// user on the preceding "Retry queued".
  final bool slow;
  final VoidCallback? onRetry;

  @override
  State<SendStatusIndicator> createState() => _SendStatusIndicatorState();
}

class _SendStatusIndicatorState extends State<SendStatusIndicator> {
  @override
  void didUpdateWidget(SendStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      final announcement = _announcementFor(context, widget.status);
      if (announcement != null) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          announcement,
          Directionality.of(context),
        );
      }
    }
  }

  /// Returns a human-readable announcement string for the given [status], or
  /// null for states that do not warrant an announcement (e.g. unknown).
  String? _announcementFor(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'sending':
        return l10n.chatSendSendingSemantic;
      case 'pending':
        return l10n.chatSendRetryQueuedSemantic;
      case 'sent':
        return widget.slow
            ? l10n.chatSendDeliveredSlowSemantic
            : l10n.chatSendDeliveredSemantic;
      case 'failed':
        return l10n.chatSendNotDeliveredSemantic;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xxs,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    switch (widget.status) {
      case 'sending':
        return Semantics(
          label: l10n.chatSendSendingSemantic,
          liveRegion: true,
          child: _StatusLabel(
            label: l10n.chatSendSending,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            indicator: SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      case 'pending':
        return Semantics(
          label: l10n.chatSendRetryQueuedSemantic,
          liveRegion: true,
          child: _StatusLabel(
            label: l10n.chatStatusRetryQueued,
            color: cs.secondary,
            indicator: Icon(
              Icons.schedule_rounded,
              size: 10,
              color: cs.secondary,
            ),
          ),
        );
      case 'sent':
        return Semantics(
          label: widget.slow
              ? l10n.chatSendDeliveredSlowSemantic
              : l10n.chatSendDeliveredSemantic,
          liveRegion: true,
          child: _StatusLabel(
            label: widget.slow
                ? l10n.chatSendDeliveredSlow
                : l10n.chatSendDelivered,
            color: cs.primary.withValues(alpha: 0.85),
            indicator: Icon(
              widget.slow ? Icons.schedule_rounded : Icons.check_rounded,
              size: 10,
              color: cs.primary.withValues(alpha: 0.85),
            ),
          ),
        );
      case 'failed':
        return Semantics(
          label: widget.onRetry != null
              ? l10n.chatSendNotDeliveredRetrySemantic
              : l10n.chatSendNotDeliveredSemantic,
          liveRegion: true,
          button: widget.onRetry != null,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onRetry,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Ink(
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 11,
                          color: cs.onError,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          l10n.chatSendFailedRetry,
                          style: style?.copyWith(
                            color: cs.onError,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
