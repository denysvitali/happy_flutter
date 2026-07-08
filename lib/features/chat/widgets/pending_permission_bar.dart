import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_tokens.dart';

/// Sticky bar above the composer when the session has pending
/// permission requests. Keeps Allow/Deny reachable on long transcripts
/// without scrolling to the tool card.
class PendingPermissionBar extends ConsumerStatefulWidget {
  const PendingPermissionBar({
    required this.sessionId,
    required this.requests,
    super.key,
    this.isSessionOnline = true,
  });

  final String sessionId;
  final Map<String, RequestInfo> requests;
  final bool isSessionOnline;

  @override
  ConsumerState<PendingPermissionBar> createState() =>
      _PendingPermissionBarState();
}

class _PendingPermissionBarState extends ConsumerState<PendingPermissionBar> {
  bool _busy = false;

  MapEntry<String, RequestInfo>? get _first {
    if (widget.requests.isEmpty) return null;
    return widget.requests.entries.first;
  }

  Future<void> _allow() async {
    final first = _first;
    if (first == null || _busy || !widget.isSessionOnline) return;
    setState(() => _busy = true);
    await HapticFeedback.mediumImpact();
    try {
      await ref
          .read(permissionsNotifierProvider.notifier)
          .allow(widget.sessionId, first.key);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.permissionActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deny() async {
    final first = _first;
    if (first == null || _busy || !widget.isSessionOnline) return;
    setState(() => _busy = true);
    await HapticFeedback.mediumImpact();
    try {
      await ref
          .read(permissionsNotifierProvider.notifier)
          .deny(widget.sessionId, first.key);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.permissionActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    if (first == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final count = widget.requests.length;
    final toolLabel = first.value.tool;
    final subtitle = count > 1
        ? '$toolLabel · +${count - 1}'
        : toolLabel;

    return Material(
      color: cs.errorContainer.withValues(alpha: 0.55),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: cs.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.permissionRequired,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onErrorContainer.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                TextButton(
                  onPressed: widget.isSessionOnline ? _deny : null,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onErrorContainer,
                    minimumSize: const Size(
                      AppTouchTarget.min,
                      AppTouchTarget.min,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.permissionDeny),
                ),
                FilledButton(
                  onPressed: widget.isSessionOnline ? _allow : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      AppTouchTarget.min,
                      AppTouchTarget.min,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.permissionAllow),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
