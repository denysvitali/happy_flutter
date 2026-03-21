/// Formats a human-readable description of a permission request action.
///
/// Used by both [PermissionFooter] (in-chat UI) and
/// [NotificationService] (lock-screen notifications).
String describePermissionAction(
  String toolName,
  Map<String, dynamic>? toolInput,
) {
  if (toolInput == null) return 'run $toolName';

  switch (toolName) {
    case 'Edit':
    case 'MultiEdit':
    case 'NotebookEdit':
      final path = toolInput['path'] as String?;
      if (path != null) {
        final short = path.length > 36
            ? '...${path.substring(path.length - 36)}'
            : path;
        return 'edit $short';
      }
      return 'edit file';
    case 'Write':
      final path = toolInput['path'] as String?;
      if (path != null) {
        final short = path.length > 36
            ? '...${path.substring(path.length - 36)}'
            : path;
        return 'write $short';
      }
      return 'write file';
    case 'Bash':
      final cmd = toolInput['command'] as String?;
      if (cmd != null) {
        final short =
            cmd.length > 42 ? '${cmd.substring(0, 42)}\u2026' : cmd;
        return 'run: $short';
      }
      return 'run bash command';
    case 'ExitPlanMode':
    case 'exit_plan_mode':
      return 'accept plan and continue';
    default:
      return 'run $toolName';
  }
}
