import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';

export 'active_session_card.dart';
export 'archived_session_card.dart';
export 'compact_active_session_card.dart';

/// Parses an avatar style string to the corresponding
/// [AvatarStyle] enum. Returns null if unknown.
AvatarStyle? parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
    'geometric' => AvatarStyle.geometric,
    'rings' => AvatarStyle.rings,
    'constellation' => AvatarStyle.constellation,
    'wave' => AvatarStyle.wave,
    'neon' => AvatarStyle.neon,
    'bloom' => AvatarStyle.bloom,
    'prism' => AvatarStyle.prism,
    _ => null,
  };
}

/// Computes todo progress, returning (completed, total) or
/// null if todos are empty or all completed.
({int completed, int total})? getTodoProgress(List<TodoItem>? todos) {
  if (todos == null || todos.isEmpty) return null;
  final total = todos.length;
  final completed = todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}

// ────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────

/// Derived display values computed from a [Session].
class SessionDerived {
  SessionDerived({
    required this.status,
    required this.avatarId,
    required this.name,
    required this.subtitle,
  });

  factory SessionDerived.from(Session session) {
    return SessionDerived(
      status: getSessionStatus(session),
      avatarId: getSessionAvatarId(session),
      name: getSessionName(session),
      subtitle: getSessionSubtitle(session),
    );
  }

  final SessionStatus status;
  final String avatarId;
  final String name;
  final String subtitle;
}

/// Builds the status text widget shown beneath the session
/// name when the session is connected and has a meaningful
/// status (thinking, permission required, etc.).
Widget? buildStatusText(SessionStatus status, TextTheme textTheme) {
  if (!status.shouldShowStatus || !status.isConnected) {
    return null;
  }
  return Text(
    status.statusText,
    style: textTheme.labelSmall?.copyWith(
      color: Color(status.statusColor),
      fontWeight: FontWeight.w500,
      fontSize: AppFontSize.xs,
    ),
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

/// Whether [activity] already says what [buildStatusText] would say.
///
/// "Bash needs approval" and "Permission required" are the same state;
/// a card renders the more specific one only.
bool activityRestatesStatus(SessionActivity? activity) =>
    activity?.kind == SessionActivityKind.permission;

/// Which kind of activity a [SessionActivity] describes.
enum SessionActivityKind {
  /// A permission request is waiting for the user.
  ///
  /// This restates `SessionStatus.permissionRequired`, so a card that
  /// renders both must drop the status line to avoid saying it twice.
  permission,

  /// A tool the agent was just approved to run.
  runningTool,

  /// The agent is thinking, with no more specific signal available.
  working,
}

/// What a session is currently doing, derived purely from in-memory
/// state (`Session.agentState` + `Session.thinking`) — no extra fetches.
class SessionActivity {
  const SessionActivity({
    required this.label,
    required this.icon,
    required this.kind,
  });

  final String label;
  final IconData icon;
  final SessionActivityKind kind;
}

/// Newest entry of [requests] by `createdAt`, or null when empty.
T? _newest<T>(Map<String, T>? requests, int? Function(T) createdAt) {
  if (requests == null || requests.isEmpty) return null;
  T? best;
  var bestAt = -1;
  for (final value in requests.values) {
    final at = createdAt(value) ?? 0;
    if (best == null || at >= bestAt) {
      best = value;
      bestAt = at;
    }
  }
  return best;
}

/// How recently a permission must have been approved for the tool it
/// covers to still be a plausible description of what is running now.
const int kRunningToolFreshnessMs = 90 * 1000;

/// Newest approved permission that is recent enough to describe the tool
/// the agent is running right now.
///
/// `completedRequests` are *finished* permission requests — approved,
/// denied or canceled — and they are never pruned, so without both a
/// status and a recency filter a card would happily report a tool the
/// user denied, or one approved an hour ago, as "Running".
CompletedRequestInfo? _recentlyApprovedTool(
  Map<String, CompletedRequestInfo>? completed,
  int nowMs,
) {
  if (completed == null || completed.isEmpty) return null;
  CompletedRequestInfo? best;
  var bestAt = -1;
  for (final value in completed.values) {
    if (value.status != 'approved') continue;
    if (value.tool.isEmpty) continue;
    final at = value.completedAt ?? value.createdAt ?? 0;
    if (nowMs - at > kRunningToolFreshnessMs) continue;
    if (at > bestAt) {
      best = value;
      bestAt = at;
    }
  }
  return best;
}

/// Resolves the one-line activity summary for [session].
///
/// Returns null when nothing is known — callers then fall back to the
/// last-message preview (and finally the project path). Never returns a
/// placeholder: an unknown activity renders no line at all.
///
/// Offline sessions never report activity: leftover `agentState`
/// requests are not cleared when presence drops, so an offline card
/// would otherwise claim a tool needs approval next to its own
/// "Last seen …" status. This matches `getSessionStatus`, which gates
/// thinking and permissionRequired on presence too.
SessionActivity? getSessionActivity(
  BuildContext context,
  Session session, {
  DateTime? now,
}) {
  if (session.presence != 'online') return null;

  final agentState = session.agentState;

  final pending = _newest(agentState?.requests, (r) => r.createdAt);
  if (pending != null && pending.tool.isNotEmpty) {
    return SessionActivity(
      label: context.l10n.sessionActivityToolApproval(pending.tool),
      icon: Icons.lock_outline,
      kind: SessionActivityKind.permission,
    );
  }

  if (!session.thinking) return null;

  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final running = _recentlyApprovedTool(agentState?.completedRequests, nowMs);
  if (running != null) {
    return SessionActivity(
      label: context.l10n.sessionActivityRunningTool(running.tool),
      icon: Icons.terminal_outlined,
      kind: SessionActivityKind.runningTool,
    );
  }
  return SessionActivity(
    label: context.l10n.sessionActivityWorking,
    icon: Icons.auto_awesome_outlined,
    kind: SessionActivityKind.working,
  );
}

/// One-line activity summary: what the session is doing right now, or
/// the last message snippet when it is idle.
///
/// Returns null when neither is known so the caller can fall back to the
/// project path instead of rendering an empty placeholder.
Widget? buildActivityLine({
  required BuildContext context,
  required Session session,
  required String? preview,
  required String? previewRole,
  required TextStyle? style,
  int maxLines = 1,
}) {
  return buildActivityLineFor(
    context: context,
    activity: getSessionActivity(context, session),
    preview: preview,
    previewRole: previewRole,
    style: style,
    maxLines: maxLines,
  );
}

/// Same as [buildActivityLine] for an already-resolved [activity].
///
/// Cards that need to know the activity kind (to suppress a status line
/// that would restate it) resolve it once and pass it in here.
Widget? buildActivityLineFor({
  required BuildContext context,
  required SessionActivity? activity,
  required String? preview,
  required String? previewRole,
  required TextStyle? style,
  int maxLines = 1,
}) {
  if (activity == null) {
    if (preview == null || preview.isEmpty) return null;
    return buildPreviewText(
      context: context,
      preview: preview,
      role: previewRole,
      style: style,
      maxLines: maxLines,
    );
  }

  final cs = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(activity.icon, size: AppIconSize.sm, color: cs.onSurfaceVariant),
      const SizedBox(width: AppSpacing.xxs),
      Flexible(
        child: Text(
          activity.label,
          style: style?.copyWith(color: cs.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    ],
  );
}

/// Builds a Telegram-style message preview with a "You: " prefix
/// for user messages in a subtle accent color.
Widget buildPreviewText({
  required BuildContext context,
  required String preview,
  required String? role,
  required TextStyle? style,
  required int maxLines,
}) {
  final cs = Theme.of(context).colorScheme;
  final isUser = role == 'user';
  final baseStyle = style?.copyWith(
    color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.high),
  );

  if (!isUser) {
    return Text(
      preview,
      style: baseStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
    );
  }

  return RichText(
    overflow: TextOverflow.ellipsis,
    maxLines: maxLines,
    text: TextSpan(
      children: [
        TextSpan(
          text: 'You: ',
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        TextSpan(text: preview, style: baseStyle),
      ],
    ),
  );
}

/// Name row: session name with trailing status dot.
///
/// Set [pulseDot] to true to force the status dot into pulse
/// animation (e.g. when the session has unread messages),
/// independent of the session's own activity state.
Widget buildNameRow({
  required String name,
  required SessionStatus sessionStatus,
  required TextStyle? style,
  Color? dotColor,
  double dotSize = 7,
  bool pulseDot = false,
  Widget? badge,
}) {
  return Row(
    children: [
      Flexible(
        child: Text(
          name,
          style: style,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      if (badge != null) ...[
        const SizedBox(width: AppSpacing.xs),
        badge,
      ],
      const SizedBox(width: AppSpacing.xsm),
      SessionStatusIndicator(
        status: sessionStatus,
        color: dotColor,
        size: dotSize,
        pulse: pulseDot,
      ),
    ],
  );
}

/// Right column: timestamp + optional unread + todo badges.
Widget buildTimestampBadges({
  required int timestamp,
  required ThemeData theme,
  required ColorScheme cs,
  int unreadCount = 0,
  ({int completed, int total})? todoProgress,
  double badgeGap = AppSpacing.xxs,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        formatTimestamp(timestamp, relative: true),
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: AppFontSize.xs,
        ),
      ),
      if (unreadCount > 0) ...[
        SizedBox(height: badgeGap),
        UnreadBadge(count: unreadCount),
      ],
      if (todoProgress != null) ...[
        SizedBox(height: badgeGap),
        TodoProgressBadge(
          completed: todoProgress.completed,
          total: todoProgress.total,
        ),
      ],
    ],
  );
}

/// Pending-archive badge.
///
/// Belongs next to the session name: rendered in the trailing column it
/// sat directly under the timestamp and read as date metadata.
class ArchiveCountdownBadge extends StatelessWidget {
  const ArchiveCountdownBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBadge(
      leading: const Icon(Icons.hourglass_bottom_outlined, size: 10),
      label: label,
      backgroundColor: cs.surfaceContainer,
      borderColor: cs.outlineVariant.withValues(alpha: AppOpacity.soft),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}

/// Shared avatar with optional draft badge.
Widget buildSessionAvatar({
  required String sessionId,
  required String avatarId,
  required String? sessionFlavor,
  required double size,
  required bool showFlavorIcon,
  required bool hasDraft,
  AvatarStyle? avatarStyle,
  bool monochrome = false,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      SessionAvatar(
        id: avatarId,
        flavor: sessionFlavor,
        size: size,
        showFlavorIcon: showFlavorIcon,
        monochrome: monochrome,
        square: true,
        style: avatarStyle,
      ),
      if (hasDraft) const DraftBadge(),
    ],
  );
}
