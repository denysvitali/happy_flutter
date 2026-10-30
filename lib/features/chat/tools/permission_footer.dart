import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/theme/app_button_style.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/permission_description.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../widgets/chat_agent_scope.dart';
import '../widgets/inline_permission_visibility.dart';
import 'permission_risk.dart';

/// Permission request UI with Allow, Allow All, and Deny buttons.
class PermissionFooter extends StatefulWidget {
  const PermissionFooter({
    required this.permission,
    required this.sessionId,
    required this.toolName,
    super.key,
    this.toolInput,
    this.flavor,
    this.isSessionOnline = true,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowForSession,
    this.onYolo,
    this.onCodexApprove,
    this.onCodexApproveForSession,
    this.onCodexAbort,
  });

  /// The permission data.
  final Map<String, dynamic> permission;

  /// The session ID for making API calls.
  final String sessionId;

  /// The tool name.
  final String toolName;

  /// The tool input (for showing what will be allowed).
  final Map<String, dynamic>? toolInput;

  /// The session flavor (e.g. 'claude', 'codex', 'agy').
  final String? flavor;

  /// Whether the session's CLI process is online.
  ///
  /// When `false` and the permission is pending, action buttons are
  /// replaced with a "Session offline" label since the CLI process
  /// that raised the permission is gone.
  final bool isSessionOnline;

  /// Callback when permission is allowed.
  final Future<void> Function()? onAllow;

  /// Callback when permission is denied.
  final Future<void> Function()? onDeny;

  /// Callback when permission is allowed for all edits.
  final Future<void> Function()? onAllowAllEdits;

  /// Callback when permission is allowed for the session.
  final Future<void> Function()? onAllowForSession;

  /// Callback when permission is allowed with YOLO mode.
  final Future<void> Function()? onYolo;

  /// Callback for Codex approve (single action).
  final Future<void> Function()? onCodexApprove;

  /// Callback for Codex approve for session.
  final Future<void> Function()? onCodexApproveForSession;

  /// Callback for Codex abort.
  final Future<void> Function()? onCodexAbort;

  @override
  State<PermissionFooter> createState() => _PermissionFooterState();
}

class _PermissionFooterState extends State<PermissionFooter> {
  bool _loading = false;
  bool _showAdvanced = false;

  @override
  void didUpdateWidget(PermissionFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.permission['status'] as String? ?? 'pending';
    if (status != 'pending' && _loading) {
      setState(() => _loading = false);
    }
  }

  Future<void> _wrap(Future<void> Function()? cb) async {
    if (cb == null || _loading) return;
    setState(() => _loading = true);
    try {
      await cb();
    } on Object catch (e) {
      final msg = e.toString();
      // Expected race conditions when server resolves/expires the
      // permission before the user acts — downgrade to info.
      final isExpectedRace =
          msg.contains('restarted') ||
          msg.contains('expired') ||
          msg.contains('no pending permission') ||
          msg.contains('not available') ||
          msg.contains('failed to resolve');
      if (isExpectedRace) {
        logger.info('Permission action skipped: $e');
      } else {
        logger.warning('Permission action failed: $e');
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final String label;
        if (msg.contains('restarted') || msg.contains('expired')) {
          label = l10n.permissionExpiredRestarted;
        } else if (msg.contains('no pending permission') ||
            msg.contains('not available') ||
            msg.contains('failed to resolve')) {
          label = l10n.permissionExpiredNoPending;
        } else {
          label = l10n.permissionActionFailed;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionDescription() =>
      describePermissionAction(widget.toolName, widget.toolInput);

  @override
  Widget build(BuildContext context) {
    final permission = widget.permission;
    final status = permission['status'] as String? ?? 'pending';
    final permissionId = permission['id'] as String?;
    return InlinePermissionVisibility(
      permissionKey: permissionId == null
          ? null
          : inlinePermissionKey(widget.sessionId, permissionId),
      active: status == 'pending',
      child: _buildCard(context, status),
    );
  }

  Widget _buildCard(BuildContext context, String status) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final toolName = widget.toolName;

    // Auto-approved requests (e.g. YOLO) leave no trace: the tool row
    // already shows that it ran.
    if (status == 'approved') return const SizedBox.shrink();
    if (status != 'pending') {
      return _AnsweredLine(
        label: status == 'denied'
            ? l10n.convPermDeniedLine
            : l10n.convPermExpiredLine,
        icon: status == 'denied'
            ? Icons.block_rounded
            : Icons.timer_off_outlined,
      );
    }

    final isPlanTool =
        toolName == 'ExitPlanMode' || toolName == 'exit_plan_mode';
    final isEditTool =
        toolName == 'Edit' ||
        toolName == 'MultiEdit' ||
        toolName == 'Write' ||
        toolName == 'NotebookEdit' ||
        isPlanTool;
    final isCodex = widget.flavor == 'codex' || toolName.startsWith('Codex');

    final scope = ChatAgentScope.maybeOf(context);
    final agent =
        scope?.agentName ??
        chatAgentDisplayName(widget.flavor) ??
        l10n.convAgentFallbackName;
    final command = permissionCommand(toolName, widget.toolInput);
    final file = permissionFilePath(widget.toolInput);
    final question = isPlanTool
        ? l10n.convPermAskPlan(agent)
        : command != null
        ? l10n.convPermAskRun(agent)
        : file != null && toolName == 'Write'
        ? l10n.convPermAskWrite(agent, _basename(file))
        : file != null
        ? l10n.convPermAskEdit(agent, _basename(file))
        : l10n.convPermAskTool(agent, toolName);
    final subject = isPlanTool ? null : command ?? file ?? _actionDescription();
    final risk = permissionRiskFor(
      toolName,
      widget.toolInput,
      workspacePath: scope?.workspacePath,
    );
    final where = scope?.whereLabel;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(
          color: cs.onSurface.withValues(alpha: AppOpacity.subtle),
          width: AppBorder.thin,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Who is asking, and where it would happen.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scope != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: scope.avatar(size: 28),
                ),
                const SizedBox(width: AppSpacing.smd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      question,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                    if (where != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          where,
                          style: AppText.secondary(theme),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (subject != null) ...[
            const SizedBox(height: AppSpacing.smd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: AppOpacity.half,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                command != null ? '\$ $subject' : subject,
                style: AppText.mono(
                  theme,
                  cs.onSurface,
                ).copyWith(fontSize: AppFontSize.md, height: 1.4),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (risk != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RiskLine(risk: risk),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (!widget.isSessionOnline)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.convPermOffline,
                style: AppText.secondary(theme),
              ),
            )
          else if (isCodex)
            _PermissionActionArea(
              loading: _loading,
              child: _CodexActionButtons(
                enabled: !_loading,
                showAdvanced: _showAdvanced,
                onToggleAdvanced: _loading
                    ? null
                    : () => setState(() => _showAdvanced = !_showAdvanced),
                onCodexApprove: widget.onCodexApprove == null
                    ? null
                    : () => _wrap(widget.onCodexApprove),
                onCodexApproveForSession:
                    widget.onCodexApproveForSession == null
                    ? null
                    : () => _wrap(widget.onCodexApproveForSession),
                onCodexAbort: widget.onCodexAbort == null
                    ? null
                    : () => _wrap(widget.onCodexAbort),
              ),
            )
          else
            _PermissionActionArea(
              loading: _loading,
              child: _ActionButtons(
                enabled: !_loading,
                isEditTool: isEditTool,
                showAdvanced: _showAdvanced,
                onToggleAdvanced: _loading
                    ? null
                    : () => setState(() => _showAdvanced = !_showAdvanced),
                onAllow: widget.onAllow == null
                    ? null
                    : () => _wrap(widget.onAllow),
                onDeny: widget.onDeny == null
                    ? null
                    : () => _wrap(widget.onDeny),
                onAllowAllEdits: widget.onAllowAllEdits == null
                    ? null
                    : () => _wrap(widget.onAllowAllEdits),
                onAllowForSession: widget.onAllowForSession == null
                    ? null
                    : () => _wrap(widget.onAllowForSession),
                onYolo: widget.onYolo == null
                    ? null
                    : () => _wrap(widget.onYolo),
              ),
            ),
        ],
      ),
    );
  }

  static String _basename(String path) {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }
}

/// Plain-language consequence: an icon and one line, warning-tinted only
/// for irreversible or outward-facing actions.
class _RiskLine extends StatelessWidget {
  const _RiskLine({required this.risk});

  final PermissionRisk risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Amber reads on dark surfaces; light mode pulls it toward the ink so
    // the line keeps text contrast without becoming a warning slab.
    final color = !risk.destructive
        ? cs.onSurfaceVariant
        : theme.brightness == Brightness.dark
        ? AppColors.warning
        : Color.lerp(AppColors.warning, cs.onSurface, 0.4)!;
    return Row(
      children: [
        Icon(risk.icon, size: AppIconSize.md, color: color),
        const SizedBox(width: AppSpacing.xsm),
        Expanded(
          child: Text(
            risk.label(AppLocalizations.of(context)),
            style: AppText.secondary(theme, color),
          ),
        ),
      ],
    );
  }
}

/// Settled request: one quiet line so the transcript explains what
/// happened without keeping a card around.
class _AnsweredLine extends StatelessWidget {
  const _AnsweredLine({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.xsm),
          Flexible(child: Text(label, style: AppText.secondary(theme, color))),
        ],
      ),
    );
  }
}

class _PermissionActionArea extends StatelessWidget {
  const _PermissionActionArea({required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          Semantics(
            liveRegion: true,
            label: AppLocalizations.of(context).permissionActionInProgress,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AppLocalizations.of(context).commonLoading,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.enabled,
    required this.isEditTool,
    required this.showAdvanced,
    required this.onToggleAdvanced,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowForSession,
    this.onYolo,
  });

  final bool enabled;
  final bool isEditTool;
  final bool showAdvanced;
  final VoidCallback? onToggleAdvanced;
  final VoidCallback? onAllow;
  final VoidCallback? onDeny;
  final VoidCallback? onAllowAllEdits;
  final VoidCallback? onAllowForSession;
  final VoidCallback? onYolo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasAdvanced = isEditTool
        ? onAllowAllEdits != null || onYolo != null
        : onAllowForSession != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: enabled ? onAllow : null,
              style: _primaryButtonStyle(theme),
              child: Text(l10n.convPermAllowOnce),
            ),
            FilledButton(
              onPressed: enabled ? onDeny : null,
              style: _denyButtonStyle(theme),
              child: Text(l10n.permissionDeny),
            ),
            if (hasAdvanced)
              _AdvancedPermissionDisclosure(
                expanded: showAdvanced,
                onPressed: onToggleAdvanced,
              ),
          ],
        ),
        if (hasAdvanced && showAdvanced)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (isEditTool && onAllowAllEdits != null)
                  _SecondaryButton(
                    label: l10n.permissionAllEdits,
                    onPressed: enabled ? onAllowAllEdits : null,
                  ),
                if (isEditTool && onYolo != null)
                  _SecondaryButton(
                    label: l10n.permissionYolo,
                    onPressed: enabled ? onYolo : null,
                  ),
                if (!isEditTool && onAllowForSession != null)
                  _SecondaryButton(
                    label: l10n.permissionForSession,
                    onPressed: enabled ? onAllowForSession : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodexActionButtons extends StatelessWidget {
  const _CodexActionButtons({
    required this.enabled,
    required this.showAdvanced,
    required this.onToggleAdvanced,
    this.onCodexApprove,
    this.onCodexApproveForSession,
    this.onCodexAbort,
  });

  final bool enabled;
  final bool showAdvanced;
  final VoidCallback? onToggleAdvanced;
  final VoidCallback? onCodexApprove;
  final VoidCallback? onCodexApproveForSession;
  final VoidCallback? onCodexAbort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: enabled ? onCodexApprove : null,
              style: _primaryButtonStyle(theme),
              child: Text(l10n.convPermAllowOnce),
            ),
            FilledButton(
              onPressed: enabled ? onCodexAbort : null,
              style: _denyButtonStyle(theme),
              child: Text(l10n.permissionStop),
            ),
            if (onCodexApproveForSession != null)
              _AdvancedPermissionDisclosure(
                expanded: showAdvanced,
                onPressed: onToggleAdvanced,
              ),
          ],
        ),
        if (onCodexApproveForSession != null && showAdvanced)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _SecondaryButton(
              label: l10n.permissionForSession,
              onPressed: enabled ? onCodexApproveForSession : null,
            ),
          ),
      ],
    );
  }
}

class _AdvancedPermissionDisclosure extends StatelessWidget {
  const _AdvancedPermissionDisclosure({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = expanded
        ? l10n.permissionHideApprovalOptions
        : l10n.permissionMoreApprovalOptions;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      expanded: expanded,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(
            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: const Size(0, AppTouchTarget.min),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
        ),
      ),
    );
  }
}

/// Primary permission action: a solid ink pill (black in light mode,
/// white in dark), the one strong control on the card. Painted through
/// [AppButtonStyle.solidFilled] so the theme gradient does not cover it.
ButtonStyle _primaryButtonStyle(ThemeData theme) {
  final cs = theme.colorScheme;
  return FilledButton.styleFrom(
    minimumSize: const Size(0, AppTouchTarget.min),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    shape: const StadiumBorder(),
    elevation: 0,
  ).merge(
    AppButtonStyle.solidFilled(
      cs,
      background: cs.onSurface,
      foreground: cs.surface,
    ),
  );
}

/// Deny: a quiet tonal pill. Declining is a normal answer, not an alarm.
ButtonStyle _denyButtonStyle(ThemeData theme) {
  final cs = theme.colorScheme;
  return FilledButton.styleFrom(
    minimumSize: const Size(0, AppTouchTarget.min),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w500,
    ),
    shape: const StadiumBorder(),
    elevation: 0,
  ).merge(
    AppButtonStyle.solidFilled(
      cs,
      background: cs.surfaceContainerHighest,
      foreground: cs.onSurface,
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: AppOpacity.half),
          width: 1,
        ),
        minimumSize: const Size(0, AppTouchTarget.min),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}

/// A simpler permission button row for quick actions.
class PermissionButtons extends StatelessWidget {
  const PermissionButtons({
    required this.status,
    super.key,
    this.onAllow,
    this.onDeny,
  });

  /// The permission status.
  final String status;

  /// Callback for allow action.
  final VoidCallback? onAllow;

  /// Callback for deny action.
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = status == 'pending';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: isPending ? onAllow : null,
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text(AppLocalizations.of(context).permissionAllow),
          style: FilledButton.styleFrom(
            elevation: 0,
            minimumSize: const Size(0, AppTouchTarget.min),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            textStyle: theme.textTheme.labelMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: isPending ? onDeny : null,
          icon: const Icon(Icons.close_rounded, size: 14),
          label: Text(AppLocalizations.of(context).permissionDeny),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            minimumSize: const Size(0, AppTouchTarget.min),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            textStyle: theme.textTheme.labelMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }
}
