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
    this.context,
  });

  final String sessionId;
  final Map<String, RequestInfo> requests;
  final bool isOnline;

  /// Optional one-line context shown beside the buttons (usually the
  /// agent's latest update, which explains *why* it is asking).
  final String? context;

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
    // Calm decision: a tonal Allow instead of a loud solid warning pill.
    final allowBg = appColors?.warningContainer ?? cs.errorContainer;
    final allowFg = appColors?.onWarningContainer ?? cs.onErrorContainer;
    final hint = widget.context?.trim();
    return Row(
      children: [
        Expanded(
          child: hint == null || hint.isEmpty
              ? const SizedBox.shrink()
              : Tooltip(
                  message: hint,
                  excludeFromSemantics: true,
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary(theme),
                  ),
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
              background: allowBg,
              foreground: allowFg,
            ).merge(_buttonStyle),
            child: Text(
              l10n.permissionAllow,
              style: AppText.label(theme, allowFg),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Claude wants to run `kubectl rollout restart…`" — the pending request
/// phrased as a decision, with the command/file in monospace.
class PermissionDecisionText extends StatelessWidget {
  const PermissionDecisionText({
    required this.agentName,
    required this.requests,
    super.key,
  });

  final String agentName;
  final Map<String, RequestInfo> requests;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final first = requests.values.first;
    final args = first.arguments is Map
        ? Map<String, dynamic>.from(first.arguments as Map)
        : const <String, dynamic>{};
    String? str(String key) {
      final v = args[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final command = str('command');
    final file = str('file_path') ?? str('path') ?? str('notebook_path');
    final (lead, subject) = switch (first.tool) {
      'Bash' || 'bash' || 'shell' when command != null => (
        l10n.rosterWantsToRun(agentName),
        command.split('\n').first,
      ),
      'Edit' || 'MultiEdit' || 'Write' || 'NotebookEdit' when file != null => (
        l10n.rosterWantsToEdit(agentName),
        file.split('/').last,
      ),
      'ExitPlanMode' ||
      'exit_plan_mode' => (l10n.rosterWantsPlanApproval(agentName), null),
      _ => (l10n.rosterWantsToUse(agentName), first.tool),
    };
    final more = requests.length > 1
        ? ' ${l10n.rosterMoreRequests(requests.length - 1)}'
        : '';
    final base = AppText.secondary(theme);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: subject == null ? lead : '$lead '),
          if (subject != null)
            TextSpan(
              text: subject,
              // The concrete command/file is the decision; it gets the
              // emphasis, the lead stays quiet.
              style: AppText.mono(
                theme,
                cs.onSurface,
              ).copyWith(fontSize: base.fontSize, fontWeight: FontWeight.w600),
            ),
          if (more.isNotEmpty)
            TextSpan(text: more, style: AppText.secondary(theme)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
