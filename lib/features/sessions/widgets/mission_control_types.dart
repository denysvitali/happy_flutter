import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';

/// Horizontal gap between a Mission Control row's lane tile and its text
/// column; dividers that align with the text use it too.
const double missionRowTextGap = AppSpacing.smd;

/// How a session is triaged in Mission Control.
enum MissionLane {
  /// Permission request pending — agent blocked on the user.
  blocked,

  /// Last message was an error (e.g. an API failure) — the agent has
  /// stopped making progress and the user should know why.
  error,

  /// Unread messages the user has not seen.
  unread,

  /// Agent working right now.
  live,

  /// Nothing happening.
  quiet,
}

/// Triages [session] into the lane that decides where it renders.
MissionLane missionLaneFor(Session session, SessionUiEntry entry) {
  final status = getSessionStatus(session);
  if (status.state == SessionState.permissionRequired) {
    return MissionLane.blocked;
  }
  if (entry.lastMessageIsError) return MissionLane.error;
  if (entry.unreadCount > 0) return MissionLane.unread;
  if (status.state == SessionState.thinking) return MissionLane.live;
  return MissionLane.quiet;
}

/// Semantic color for a Mission Control lane.
Color missionLaneColor(BuildContext context, MissionLane lane) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final appColors = theme.extension<AppColorScheme>();
  return switch (lane) {
    MissionLane.blocked => appColors?.warning ?? cs.error,
    MissionLane.error => cs.error,
    MissionLane.unread => cs.primary,
    MissionLane.live => cs.tertiary,
    MissionLane.quiet => cs.onSurfaceVariant,
  };
}

/// Low-emphasis container color for a Mission Control lane.
Color missionLaneContainerColor(BuildContext context, MissionLane lane) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final appColors = theme.extension<AppColorScheme>();
  if (lane == MissionLane.blocked && appColors != null) {
    return appColors.warningContainer;
  }
  return Color.alphaBlend(
    missionLaneColor(context, lane).withValues(alpha: 0.11),
    cs.surfaceContainerLow,
  );
}

/// Icon that makes each lane distinguishable without relying on color.
IconData missionLaneIcon(MissionLane lane) => switch (lane) {
  MissionLane.blocked => Icons.lock_clock_rounded,
  MissionLane.error => Icons.error_outline_rounded,
  MissionLane.unread => Icons.mark_chat_unread_rounded,
  MissionLane.live => Icons.auto_awesome_rounded,
  MissionLane.quiet => Icons.bedtime_outlined,
};

/// Localized, sentence-case label for a Mission Control lane.
String missionLaneLabel(BuildContext context, MissionLane lane) {
  final l10n = context.l10n;
  return switch (lane) {
    MissionLane.blocked => l10n.missionControlStatBlocked,
    MissionLane.error => l10n.chatSessionFailed,
    MissionLane.unread => l10n.missionControlStatUnread,
    MissionLane.live => l10n.missionControlStatWorking,
    MissionLane.quiet => l10n.chatSessionQuiet,
  };
}

/// Sentence-case title for a lane used as a heading or filter label.
///
/// [missionLaneLabel] stays lowercase because it also reads inside counts
/// such as "2 working".
String missionLaneTitle(BuildContext context, MissionLane lane) {
  final l10n = context.l10n;
  return switch (lane) {
    MissionLane.blocked => l10n.missionLaneTitleBlocked,
    MissionLane.error => l10n.missionLaneTitleError,
    MissionLane.unread => l10n.missionLaneTitleUnread,
    MissionLane.live => l10n.missionLaneTitleLive,
    MissionLane.quiet => l10n.missionLaneTitleQuiet,
  };
}

/// Lowercase "1 blocked · 2 working" summary of the non-quiet lanes, in
/// urgency order. Returns null when every session is quiet.
String? missionLaneSummary(BuildContext context, Map<MissionLane, int> counts) {
  final parts = [
    for (final lane in MissionLane.values)
      if (lane != MissionLane.quiet && (counts[lane] ?? 0) > 0)
        '${counts[lane]} ${lane == MissionLane.error ? context.l10n.missionControlStatError : missionLaneLabel(context, lane)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Most urgent lane present in [counts], or [MissionLane.quiet].
MissionLane missionTopLane(Map<MissionLane, int> counts) {
  for (final lane in MissionLane.values) {
    if ((counts[lane] ?? 0) > 0) return lane;
  }
  return MissionLane.quiet;
}

/// Only assistant activity can be presented as a result ready to review.
String missionUnreadOutcome(BuildContext context, SessionUiEntry entry) {
  return entry.lastMessageRole == 'agent' ||
          entry.lastMessageRole == 'assistant'
      ? '${context.l10n.chatSessionResultsReady} · ${entry.unreadCount}'
      : context.l10n.missionControlNewCount(entry.unreadCount);
}

/// Formats a running duration as `12s`, `4m 05s` or `1h 12m`.
String formatElapsedShort(int millis) {
  final seconds = (millis < 0 ? 0 : millis) ~/ 1000;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '${minutes}m ${(seconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// Shortens a display path to its last two segments.
String missionShortPath(String displayPath) {
  final segments = displayPath
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '~')
      .toList();
  if (segments.isEmpty) return displayPath;
  if (segments.length == 1) return segments.single;
  return segments.sublist(segments.length - 2).join('/');
}

/// Short host for the workspace line.
String missionShortHost(String machineName) {
  var name = machineName.trim();
  if (name.isEmpty) return name;
  final paren = name.indexOf(' (');
  if (paren > 0) name = name.substring(0, paren);
  final at = name.lastIndexOf('@');
  if (at >= 0 && at < name.length - 1) {
    final host = name.substring(at + 1);
    // Devices without a hostname report `user@(none)`; the user is the only
    // meaningful part left.
    final unnamed =
        host.startsWith('(') || host == 'localhost' || host == 'none';
    name = unnamed && at > 0 ? name.substring(0, at) : host;
  }
  final parts = name.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.length >= 3 && name.length > 14) {
    return parts.take(2).join('-');
  }
  return name;
}
