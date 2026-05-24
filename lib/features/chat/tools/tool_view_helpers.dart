import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'tool_status_indicator.dart' show ToolState;

/// Duration before auto-collapsing a completed/error tool.
const kAutoCollapseDelay = Duration(seconds: 8);

/// Parses a tool state string into [ToolState].
///
/// Null or unknown values map to [ToolState.pending].
ToolState parseToolState(String? state) {
  switch (state) {
    case 'running':
      return ToolState.running;
    case 'completed':
      return ToolState.completed;
    case 'error':
      return ToolState.error;
    default:
      return ToolState.pending;
  }
}

/// Whether a permission map represents a pending (unresolved) request.
bool isPermissionPending(Map<String, dynamic>? permission) {
  if (permission == null) return false;
  final status = permission['status'];
  return status != 'approved' &&
      status != 'denied' &&
      status != 'canceled';
}

/// Whether a permission was not denied or canceled (still relevant to show).
bool isPermissionNotDeniedOrCanceled(Map<String, dynamic>? permission) {
  if (permission == null) return false;
  final status = permission['status'];
  return status != 'denied' && status != 'canceled';
}

/// Returns the accent/background color for a given tool state.
Color stateColor(ToolState state, ColorScheme cs) {
  switch (state) {
    case ToolState.running:
      return cs.primary;
    case ToolState.completed:
      return AppColors.success;
    case ToolState.error:
      return cs.error;
    case ToolState.pending:
      return cs.onSurfaceVariant;
  }
}

/// Returns label text for the status badge.
String statusBadgeLabel(ToolState state) {
  switch (state) {
    case ToolState.running:
      return 'Running';
    case ToolState.completed:
      return 'Done';
    case ToolState.error:
      return 'Error';
    case ToolState.pending:
      return 'Pending';
  }
}

/// Accent color for permission-required state (orange).
const Color permissionColor = AppColors.warning;

/// Map of MCP server name tokens to representative emojis.
const Map<String, String> mcpServerEmojis = {
  'linear': '\u{1F4CB}',
  'github': '\u{1F4BE}',
  'gitlab': '\u{1F9A8}',
  'jira': '\u{1F4DD}',
  'slack': '\u{1F4AC}',
  'notion': '\u{1F4D3}',
  'postgres': '\u{1F5C3}',
  'mysql': '\u{1F5C3}',
  'sqlite': '\u{1F5C3}',
  'filesystem': '\u{1F4C1}',
  'brave': '\u{1F310}',
  'puppeteer': '\u{1F916}',
  'fetch': '\u{1F310}',
  'memory': '\u{1F9E0}',
  'everything': '\u{1F50D}',
  'sequential': '\u{1F4BB}',
};

/// Resolves a representative emoji from an MCP server name token.
String mcpServerEmoji(String serverToken) {
  final key = serverToken.toLowerCase();
  for (final entry in mcpServerEmojis.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return '\u{1F527}'; // wrench fallback
}

/// Permission action kinds emitted from [ToolView].
enum PermissionActionKind {
  allow,
  deny,
  allowAllEdits,
  allowForSession,
  yolo,
  codexApprove,
  codexApproveForSession,
  codexAbort,
}

/// Structured permission action payload for tool permission interactions.
class PermissionAction {
  const PermissionAction({
    required this.kind,
    required this.sessionId,
    required this.permissionId,
    required this.toolName,
    this.toolInput,
  });

  final PermissionActionKind kind;
  final String sessionId;
  final String permissionId;
  final String toolName;
  final Map<String, dynamic>? toolInput;
}

/// Optional delegate for handling permission actions.
typedef PermissionActionDelegate =
    Future<void> Function(PermissionAction action);
