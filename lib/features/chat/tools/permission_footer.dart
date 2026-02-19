import 'package:flutter/material.dart';

/// Permission request UI with Allow, Allow All, and Deny buttons.
class PermissionFooter extends StatelessWidget {

  const PermissionFooter({
    required this.permission,
    required this.sessionId,
    required this.toolName,
    super.key,
    this.toolInput,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowForSession,
  });
  /// The permission data.
  final Map<String, dynamic> permission;

  /// The session ID for making API calls.
  final String sessionId;

  /// The tool name.
  final String toolName;

  /// The tool input (for showing what will be allowed).
  final Map<String, dynamic>? toolInput;

  /// Callback when permission is allowed.
  final VoidCallback? onAllow;

  /// Callback when permission is denied.
  final VoidCallback? onDeny;

  /// Callback when permission is allowed for all edits.
  final VoidCallback? onAllowAllEdits;

  /// Callback when permission is allowed for the session.
  final VoidCallback? onAllowForSession;

  String _actionDescription() {
    if (toolInput == null) return 'run $toolName';
    final input = toolInput!;

    switch (toolName) {
      case 'Edit':
      case 'MultiEdit':
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
          final short = cmd.length > 42 ? '${cmd.substring(0, 42)}…' : cmd;
          return 'run: $short';
        }
        return 'run bash command';
      default:
        return 'run $toolName';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = permission['status'] as String? ?? 'pending';

    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isDenied = status == 'denied';

    final mode = permission['mode'] as String?;
    final isApprovedViaAllEdits = isApproved && mode == 'acceptEdits';

    final allowedTools = permission['allowedTools'] as List<String>?;
    final isApprovedForSession =
        isApproved &&
        allowedTools != null &&
        allowedTools.contains(toolName);

    final isEditTool = toolName == 'Edit' || toolName == 'MultiEdit';

    final warningAmber = const Color(0xFFFFF8E1);
    final warningBorder = const Color(0xFFFFB300);

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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: _ActionButtons(
                isPending: isPending,
                isEditTool: isEditTool,
                isApproved: isApproved,
                isDenied: isDenied,
                isApprovedViaAllEdits: isApprovedViaAllEdits,
                isApprovedForSession: isApprovedForSession,
                onAllow: onAllow,
                onDeny: onDeny,
                onAllowAllEdits: onAllowAllEdits,
                onAllowForSession: onAllowForSession,
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
                vertical: 9,
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
              vertical: 9,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
