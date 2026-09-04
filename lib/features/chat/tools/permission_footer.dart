import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/permission_description.dart';

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final permission = widget.permission;
    final toolName = widget.toolName;

    final status = permission['status'] as String? ?? 'pending';

    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    // Don't render anything for auto-approved permissions (e.g. Yolo mode).
    if (isApproved) return const SizedBox.shrink();

    final isPlanTool =
        toolName == 'ExitPlanMode' || toolName == 'exit_plan_mode';

    final isEditTool =
        toolName == 'Edit' ||
        toolName == 'MultiEdit' ||
        toolName == 'Write' ||
        toolName == 'NotebookEdit' ||
        isPlanTool;

    final isCodex = widget.flavor == 'codex' || toolName.startsWith('Codex');

    final isDark = theme.brightness == Brightness.dark;
    // Adaptive warning colours — amber tint in light mode, dimmed in dark.
    final warningBg = isDark
        ? AppColors.permissionSurfaceDark
        : AppColors.permissionSurfaceLight;
    final warningBorder = isDark
        ? AppColors.permissionBorderDark
        : AppColors.permissionBorderLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, AppSpacing.xs),
      decoration: BoxDecoration(
        color: isPending ? warningBg : theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: isPending
              ? warningBorder.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 13,
                  color: isPending
                      ? AppColors.warning
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPending
                        ? l10n.permissionRequired
                        : isApproved
                        ? l10n.permissionApproved
                        : l10n.permissionDeniedLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? AppColors.warning
                          : isApproved
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action description
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Text(
              _actionDescription(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New', 'Courier'],
                fontSize: 11.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (isPending) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: warningBorder.withValues(alpha: 0.25),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: !widget.isSessionOnline
                  ? Text(
                      l10n.permissionSessionOffline,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : isCodex
                  ? _PermissionActionArea(
                      loading: _loading,
                      child: _CodexActionButtons(
                        enabled: !_loading,
                        showAdvanced: _showAdvanced,
                        onToggleAdvanced: _loading
                            ? null
                            : () => setState(
                                () => _showAdvanced = !_showAdvanced,
                              ),
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
                  : _PermissionActionArea(
                      loading: _loading,
                      child: _ActionButtons(
                        enabled: !_loading,
                        isEditTool: isEditTool,
                        showAdvanced: _showAdvanced,
                        onToggleAdvanced: _loading
                            ? null
                            : () => setState(
                                () => _showAdvanced = !_showAdvanced,
                              ),
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
            ),
          ],
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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
          children: [
            ElevatedButton.icon(
              onPressed: enabled ? onAllow : null,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: Text(l10n.permissionAllow),
              style: _primaryButtonStyle(theme),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? onDeny : null,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: Text(l10n.permissionDeny),
              style: _denyButtonStyle(theme),
            ),
          ],
        ),
        if (hasAdvanced) ...[
          const SizedBox(height: AppSpacing.xxs),
          _AdvancedPermissionDisclosure(
            expanded: showAdvanced,
            onPressed: onToggleAdvanced,
          ),
          if (showAdvanced)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
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
          children: [
            ElevatedButton.icon(
              onPressed: enabled ? onCodexApprove : null,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: Text(l10n.permissionYes),
              style: _primaryButtonStyle(
                theme,
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? onCodexAbort : null,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: Text(l10n.permissionStop),
              style: _denyButtonStyle(theme),
            ),
          ],
        ),
        if (onCodexApproveForSession != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          _AdvancedPermissionDisclosure(
            expanded: showAdvanced,
            onPressed: onToggleAdvanced,
          ),
          if (showAdvanced)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _SecondaryButton(
                label: l10n.permissionForSession,
                onPressed: enabled ? onCodexApproveForSession : null,
              ),
            ),
        ],
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
            minimumSize: const Size(0, AppTouchTarget.min),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle(
  ThemeData theme, {
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  return ElevatedButton.styleFrom(
    backgroundColor: backgroundColor ?? theme.colorScheme.primary,
    foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
    minimumSize: const Size(0, AppTouchTarget.min),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.smd,
      vertical: AppSpacing.sm,
    ),
    textStyle: theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    elevation: 0,
  );
}

ButtonStyle _denyButtonStyle(ThemeData theme) {
  return OutlinedButton.styleFrom(
    foregroundColor: theme.colorScheme.error,
    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
    minimumSize: const Size(0, AppTouchTarget.min),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.smd,
      vertical: AppSpacing.sm,
    ),
    textStyle: theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
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
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
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
        ElevatedButton.icon(
          onPressed: isPending ? onAllow : null,
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text(AppLocalizations.of(context).permissionAllow),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
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
