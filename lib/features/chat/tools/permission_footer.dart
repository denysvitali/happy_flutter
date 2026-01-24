import 'package:flutter/material.dart';

/// Permission request UI with Allow, Allow All, and Deny buttons.
class PermissionFooter extends StatelessWidget {
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

  const PermissionFooter({
    super.key,
    required this.permission,
    required this.sessionId,
    required this.toolName,
    this.toolInput,
    this.onAllow,
    this.onDeny,
    this.onAllowAllEdits,
    this.onAllowForSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = permission['status'] as String? ?? 'pending';

    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isDenied = status == 'denied';

    // Check for Codex-specific mode
    final mode = permission['mode'] as String?;
    final isApprovedViaAllEdits = isApproved && mode == 'acceptEdits';

    // Check for allowed tools (for session approval)
    final allowedTools = permission['allowedTools'] as List<String>?;
    final isApprovedForSession =
        isApproved && allowedTools != null && allowedTools.contains(toolName);

    final isEditTool = toolName == 'Edit' || toolName == 'MultiEdit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Allow button
          _buildButton(
            context: context,
            label: 'Allow',
            isActive: isPending,
            isSelected:
                isApproved && !isApprovedViaAllEdits && !isApprovedForSession,
            onPressed: isPending ? onAllow : null,
          ),
          // Allow All Edits button - only for Edit/MultiEdit tools
          if (isEditTool && isPending)
            _buildButton(
              context: context,
              label: 'Allow All Edits',
              isActive: true,
              isSelected: isApprovedViaAllEdits,
              onPressed: onAllowAllEdits,
            ),
          // Allow for session button - for non-edit tools
          if (!isEditTool && isPending)
            _buildButton(
              context: context,
              label: 'Allow for Session',
              isActive: true,
              isSelected: isApprovedForSession,
              onPressed: onAllowForSession,
            ),
          // Deny button
          _buildButton(
            context: context,
            label: 'Deny',
            isActive: isPending,
            isSelected: isDenied,
            onPressed: isPending ? onDeny : null,
            isDenyButton: true,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required bool isActive,
    required bool isSelected,
    required VoidCallback? onPressed,
    bool isDenyButton = false,
  }) {
    final theme = Theme.of(context);

    Color textColor;
    if (isDenyButton) {
      textColor = isSelected
          ? theme.colorScheme.onSurface
          : theme.colorScheme.error;
    } else {
      textColor = isSelected
          ? theme.colorScheme.onSurface
          : (isActive ? theme.colorScheme.primary : theme.colorScheme.outline);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simpler permission button row for quick actions.
class PermissionButtons extends StatelessWidget {
  /// The permission status.
  final String status;

  /// Callback for allow action.
  final VoidCallback? onAllow;

  /// Callback for deny action.
  final VoidCallback? onDeny;

  const PermissionButtons({
    super.key,
    required this.status,
    this.onAllow,
    this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = status == 'pending';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: isPending ? onAllow : null,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
          ),
          child: const Text('Allow'),
        ),
        TextButton(
          onPressed: isPending ? onDeny : null,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Deny'),
        ),
      ],
    );
  }
}
