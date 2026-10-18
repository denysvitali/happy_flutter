import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_button_style.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';

/// One-line Allow/Deny for the oldest pending permission request, so a
/// blocked agent unblocks straight from the sessions list. Mirrors the
/// handler in `PendingPermissionBar`.
class InlinePermissionActions extends ConsumerStatefulWidget {
  const InlinePermissionActions({
    required this.sessionId,
    required this.requests,
    required this.isOnline,
    super.key,
  });

  final String sessionId;
  final Map<String, RequestInfo> requests;
  final bool isOnline;

  @override
  ConsumerState<InlinePermissionActions> createState() =>
      _InlinePermissionActionsState();
}

class _InlinePermissionActionsState
    extends ConsumerState<InlinePermissionActions> {
  bool _busy = false;

  static const _buttonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(64, 32)),
    fixedSize: WidgetStatePropertyAll(Size.fromHeight(32)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  Future<void> _act(bool allow) async {
    if (_busy || !widget.isOnline || widget.requests.isEmpty) return;
    final requestId = widget.requests.keys.first;
    setState(() => _busy = true);
    await HapticFeedback.mediumImpact();
    try {
      final notifier = ref.read(permissionsNotifierProvider.notifier);
      if (allow) {
        await notifier.allow(widget.sessionId, requestId);
      } else {
        await notifier.deny(widget.sessionId, requestId);
      }
    } catch (_) {
      if (mounted) context.showSnack(context.l10n.permissionActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final accent = appColors?.warning ?? cs.error;
    final onAccent = appColors?.onWarning ?? cs.onError;
    final first = widget.requests.entries.first;
    final count = widget.requests.length;
    final label = count > 1
        ? '${first.value.tool} · +${count - 1}'
        : first.value.tool;
    return Row(
      children: [
        Icon(Icons.shield_outlined, size: AppIconSize.sm, color: accent),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(theme, accent),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (_busy)
          const SizedBox.square(
            dimension: AppIconSize.md,
            child: AppCircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          TextButton(
            onPressed: widget.isOnline ? () => _act(false) : null,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ).merge(_buttonStyle),
            child: Text(
              l10n.permissionDeny,
              style: AppText.label(theme, cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: widget.isOnline ? () => _act(true) : null,
            style: AppButtonStyle.solidFilled(
              cs,
              background: accent,
              foreground: onAccent,
            ).merge(_buttonStyle),
            child: Text(
              l10n.permissionAllow,
              style: AppText.label(theme, onAccent),
            ),
          ),
        ],
      ],
    );
  }
}
