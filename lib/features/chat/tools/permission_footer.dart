import 'package:flutter/material.dart';

import '../../../core/services/logger_service.dart' show logger;

/// Permission request UI with Allow, Allow All, and Deny buttons.
class PermissionFooter extends StatefulWidget {

  const PermissionFooter({
    required this.permission,
    required this.sessionId,
    required this.toolName,
    super.key,
    this.toolInput,
    this.flavor,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowBypass,
    this.onAllowForSession,
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

  /// The session flavor (e.g. 'claude', 'codex', 'gemini').
  final String? flavor;

  /// Callback when permission is allowed.
  final Future<void> Function()? onAllow;

  /// Callback when permission is denied.
  final Future<void> Function()? onDeny;

  /// Callback when permission is allowed for all edits.
  final Future<void> Function()? onAllowAllEdits;

  /// Callback when permission is allowed in bypass (yolo) mode.
  final Future<void> Function()? onAllowBypass;

  /// Callback when permission is allowed for the session.
  final Future<void> Function()? onAllowForSession;

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

  @override
  void didUpdateWidget(PermissionFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status =
        widget.permission['status'] as String? ?? 'pending';
    if (status != 'pending' && _loading) {
      setState(() => _loading = false);
    }
  }

  Future<void> _wrap(Future<void> Function()? cb) async {
    if (cb == null || _loading) return;
    setState(() => _loading = true);
    try {
      await cb();
    } on Exception catch (e) {
      logger.error('Permission action failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionDescription() {
    if (widget.toolInput == null) return 'run ${widget.toolName}';
    final input = widget.toolInput!;

    switch (widget.toolName) {
      case 'Edit':
      case 'MultiEdit':
      case 'NotebookEdit':
        final path = input['path'] as String?;
        if (path != null) {
          final short = path.length > 36
              ? '...${path.substring(path.length - 36)}'
              : path;
          return 'edit $short';
        }
        return 'edit file';
      case 'Write':
        final path = input['path'] as String?;
        if (path != null) {
          final short = path.length > 36
              ? '...${path.substring(path.length - 36)}'
              : path;
          return 'write $short';
        }
        return 'write file';
      case 'Bash':
        final cmd = input['command'] as String?;
        if (cmd != null) {
          final short =
              cmd.length > 42 ? '${cmd.substring(0, 42)}…' : cmd;
          return 'run: $short';
        }
        return 'run bash command';
      case 'ExitPlanMode':
      case 'exit_plan_mode':
        return 'accept plan and continue';
      default:
        return 'run ${widget.toolName}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permission = widget.permission;
    final toolName = widget.toolName;

    final status = permission['status'] as String? ?? 'pending';

    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isDenied = status == 'denied';

    final mode = permission['mode'] as String?;
    final isApprovedViaAllEdits = isApproved && mode == 'acceptEdits';

    final rawAllowedTools =
        permission['allowedTools'] as List<dynamic>?;
    final allowedTools = rawAllowedTools?.cast<String>();

    final isApprovedForSession =
        isApproved &&
        allowedTools != null &&
        allowedTools.any(
          (t) => t == toolName || t.startsWith('$toolName('),
        );

    final isPlanTool =
        toolName == 'ExitPlanMode' ||
        toolName == 'exit_plan_mode';

    final isEditTool = toolName == 'Edit' ||
        toolName == 'MultiEdit' ||
        toolName == 'Write' ||
        toolName == 'NotebookEdit' ||
        isPlanTool;

    final isCodex =
        widget.flavor == 'codex' || toolName.startsWith('Codex');

    const warningAmber = Color(0xFFFFF8E1);
    const warningBorder = Color(0xFFFFB300);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      decoration: BoxDecoration(
        color: isPending
            ? warningAmber
            : theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: isPending
              ? warningBorder.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10),
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
                      ? const Color(0xFFE65100)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPending
                        ? 'Permission required'
                        : isApproved
                            ? 'Approved'
                            : 'Denied',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? const Color(0xFFE65100)
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
              child: _loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isCodex
                      ? _CodexActionButtons(
                          onCodexApprove: () =>
                              _wrap(widget.onCodexApprove),
                          onCodexApproveForSession: () =>
                              _wrap(widget.onCodexApproveForSession),
                          onCodexAbort: () =>
                              _wrap(widget.onCodexAbort),
                        )
                      : isPlanTool
                          ? _PlanActionButtons(
                              isPending: isPending,
                              onAllowAllEdits: () =>
                                  _wrap(widget.onAllowAllEdits),
                              onAllowBypass: () =>
                                  _wrap(widget.onAllowBypass),
                              onDeny: () => _wrap(widget.onDeny),
                            )
                          : _ActionButtons(
                              isPending: isPending,
                              isEditTool: isEditTool,
                              isApproved: isApproved,
                              isDenied: isDenied,
                              isApprovedViaAllEdits:
                                  isApprovedViaAllEdits,
                              isApprovedForSession:
                                  isApprovedForSession,
                              onAllow: () =>
                                  _wrap(widget.onAllow),
                              onDeny: () =>
                                  _wrap(widget.onDeny),
                              onAllowAllEdits: () =>
                                  _wrap(widget.onAllowAllEdits),
                              onAllowForSession: () =>
                                  _wrap(widget.onAllowForSession),
                            ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {

  const _ActionButtons({
    required this.isPending,
    required this.isEditTool,
    required this.isApproved,
    required this.isDenied,
    required this.isApprovedViaAllEdits,
    required this.isApprovedForSession,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowForSession,
  });
  final bool isPending;
  final bool isEditTool;
  final bool isApproved;
  final bool isDenied;
  final bool isApprovedViaAllEdits;
  final bool isApprovedForSession;
  final VoidCallback? onAllow;
  final VoidCallback? onDeny;
  final VoidCallback? onAllowAllEdits;
  final VoidCallback? onAllowForSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Primary allow button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isPending ? onAllow : null,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: const Text('Allow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              textStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              elevation: 0,
            ),
          ),
        ),

        // Secondary allow (all edits / for session)
        if (isPending) ...[
          const SizedBox(width: 6),
          if (isEditTool)
            _SecondaryButton(
              label: 'All edits',
              onPressed: onAllowAllEdits,
            )
          else
            _SecondaryButton(
              label: 'For session',
              onPressed: onAllowForSession,
            ),
        ],

        const SizedBox(width: 6),

        // Deny button
        OutlinedButton.icon(
          onPressed: isPending ? onDeny : null,
          icon: const Icon(Icons.close_rounded, size: 14),
          label: const Text('Deny'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanActionButtons extends StatelessWidget {
  const _PlanActionButtons({
    required this.isPending,
    this.onAllowAllEdits,
    this.onAllowBypass,
    this.onDeny,
  });

  final bool isPending;
  final VoidCallback? onAllowAllEdits;
  final VoidCallback? onAllowBypass;
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Accept edits
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isPending ? onAllowAllEdits : null,
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: const Text('Accept edits'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor:
                      theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle:
                      theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Yolo mode
            _SecondaryButton(
              label: 'Yolo',
              onPressed: isPending ? onAllowBypass : null,
            ),
            const SizedBox(width: 6),
            // Deny
            OutlinedButton.icon(
              onPressed: isPending ? onDeny : null,
              icon:
                  const Icon(Icons.close_rounded, size: 14),
              label: const Text('Deny'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error
                      .withValues(alpha: 0.5),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                textStyle:
                    theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodexActionButtons extends StatelessWidget {

  const _CodexActionButtons({
    this.onCodexApprove,
    this.onCodexApproveForSession,
    this.onCodexAbort,
  });

  /// Callback for the "Yes" (approve once) button.
  final VoidCallback? onCodexApprove;

  /// Callback for the "For session" (approve for session) button.
  final VoidCallback? onCodexApproveForSession;

  /// Callback for the "Stop" (abort) button.
  final VoidCallback? onCodexAbort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Yes — primary green button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onCodexApprove,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: const Text('Yes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              textStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(width: 6),

        // For session — outlined secondary button
        _SecondaryButton(
          label: 'For session',
          onPressed: onCodexApproveForSession,
        ),

        const SizedBox(width: 6),

        // Stop — outlined error button
        OutlinedButton.icon(
          onPressed: onCodexAbort,
          icon: const Icon(Icons.close_rounded, size: 14),
          label: const Text('Stop'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {

  const _SecondaryButton({
    required this.label,
    this.onPressed,
  });
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Text(label),
    );
  }
}

/// A simpler permission button row for quick actions.
class PermissionButtons extends StatelessWidget {

  const PermissionButtons({
    required this.status, super.key,
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: isPending ? onAllow : null,
          icon: const Icon(Icons.check_rounded, size: 14),
          label: const Text('Allow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.labelMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: isPending ? onDeny : null,
          icon: const Icon(Icons.close_rounded, size: 14),
          label: const Text('Deny'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.labelMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ],
    );
  }
}
