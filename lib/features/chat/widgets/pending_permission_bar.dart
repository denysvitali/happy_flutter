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
  /// Requests still awaiting an answer: a decision that is syncing in
  /// [permissionOperationsNotifierProvider] already counts as answered.
  Map<String, RequestInfo> _undecided(Map<String, PermissionOperation> ops) {
    if (ops.isEmpty) return widget.requests;
    return {
      for (final MapEntry(:key, :value) in widget.requests.entries)
        if (decidedPermission(ops, widget.sessionId, key) == null) key: value,
    };
  }

  MapEntry<String, RequestInfo>? get _first {
    final requests = _undecided(ref.read(permissionOperationsNotifierProvider));
    if (requests.isEmpty) return null;
    return requests.entries.first;
  }

  /// Sends the decision in the background; the bar moves on at once and a
  /// failure brings the request back (reported app-wide).
  Future<void> _decide({required bool allow}) async {
    final first = _first;
    if (first == null || !widget.isSessionOnline) return;
    ref
        .read(permissionOperationsNotifierProvider.notifier)
        .submit(
          PermissionDecision(
            sessionId: widget.sessionId,
            permissionId: first.key,
            allow: allow,
          ),
        );
    await HapticFeedback.mediumImpact();
  }

  Future<void> _allow() => _decide(allow: true);

  Future<void> _deny() => _decide(allow: false);

  @override
  Widget build(BuildContext context) {
    final requests = _undecided(
      ref.watch(permissionOperationsNotifierProvider),
    );
    if (requests.isEmpty) return const SizedBox.shrink();
    // Ask once: while the in-transcript card for every pending request is
    // on screen, that card is the decision surface and this bar stays out
    // of the way. It returns when the card scrolls off (or is not built).
    return ValueListenableBuilder<Set<String>>(
      valueListenable: visibleInlinePermissions,
      builder: (context, visible, _) {
        final allInline = requests.keys.every(
          (id) => visible.contains(inlinePermissionKey(widget.sessionId, id)),
        );
        if (allInline) return const SizedBox.shrink();
        return _buildBar(context, requests);
      },
    );
  }

  Widget _buildBar(BuildContext context, Map<String, RequestInfo> requests) {
    final first = requests.entries.first;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final count = requests.length;
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
              ...[
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
