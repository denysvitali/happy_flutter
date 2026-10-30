import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_button_style.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/permission_description.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import 'inline_permission_visibility.dart';

/// Sticky bar above the composer when the session has pending
/// permission requests. Keeps Allow/Deny reachable on long transcripts
/// without scrolling to the tool card.
class PendingPermissionBar extends ConsumerStatefulWidget {
  const PendingPermissionBar({
    required this.sessionId,
    required this.requests,
    super.key,
    this.isSessionOnline = true,
    this.agentName,
    this.avatar,
  });

  final String sessionId;
  final Map<String, RequestInfo> requests;
  final bool isSessionOnline;

  /// Display name of the asking agent ("Claude"); a localized fallback is
  /// used when null.
  final String? agentName;

  /// The asking agent's avatar; a neutral mark when null.
  final Widget? avatar;

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
    if (widget.requests.isEmpty) return const SizedBox.shrink();
    // Ask once: while the in-transcript card for every pending request is
    // on screen, that card is the decision surface and this bar stays out
    // of the way. It returns when the card scrolls off (or is not built).
    return ValueListenableBuilder<Set<String>>(
      valueListenable: visibleInlinePermissions,
      builder: (context, visible, _) {
        final allInline = widget.requests.keys.every(
          (id) => visible.contains(inlinePermissionKey(widget.sessionId, id)),
        );
        if (allInline) return const SizedBox.shrink();
        return _buildBar(context);
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    final first = _first!;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final count = widget.requests.length;
    final args = first.value.arguments;
    final detail = describePermissionAction(
      first.value.tool,
      args is Map<String, dynamic> ? args : null,
    );
    final subtitle = count > 1
        ? '$detail · ${l10n.convPermBarMore(count - 1)}'
        : detail;
    final agent = widget.agentName ?? l10n.convAgentFallbackName;

    return Material(
      color: cs.surfaceContainerLow,
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
              if (widget.avatar case final avatar?)
                avatar
              else
                Icon(
                  Icons.front_hand_outlined,
                  size: AppIconSize.xl,
                  color: AppColors.warning,
                ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.convPermBarTitle(agent),
                      style: AppText.title(theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppText.mono(theme, cs.onSurfaceVariant),
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
                  child: AppCircularProgressIndicator(strokeWidth: 2),
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
                  style:
                      FilledButton.styleFrom(
                        minimumSize: const Size(
                          AppTouchTarget.min,
                          AppTouchTarget.min,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        shape: const StadiumBorder(),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).merge(
                        AppButtonStyle.solidFilled(
                          cs,
                          background: cs.onSurface,
                          foreground: cs.surface,
                        ),
                      ),
                  child: Text(l10n.convPermAllowOnce),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
