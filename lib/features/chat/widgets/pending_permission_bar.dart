import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';

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
        context.showSnack(context.l10n.permissionActionFailed);
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
        context.showSnack(context.l10n.permissionActionFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    if (first == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final count = widget.requests.length;
    final toolLabel = first.value.tool;
    final subtitle = count > 1 ? '$toolLabel · +${count - 1}' : toolLabel;

    // Aurora warning glass: warning-tinted fill with a hairline seam so the
    // highest-stakes surface reads urgent without a red slab.
    return Material(
      color: Color.alphaBlend(
        AppColors.warning.withValues(alpha: 0.14),
        cs.surfaceContainerLow,
      ),
      shape: Border(
        top: BorderSide(color: appCs.glassBorder, width: AppBorder.hairline),
      ),
      clipBehavior: Clip.antiAlias,
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
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.smd),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 17,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.permissionRequired,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
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
                    foregroundColor: cs.onSurfaceVariant,
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
