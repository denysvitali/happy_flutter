import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/utils/session_status.dart';

/// How a session is triaged in Mission Control.
enum MissionLane {
  /// Permission request pending — agent blocked on the user.
  blocked,

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
  MissionLane.unread => Icons.mark_chat_unread_rounded,
  MissionLane.live => Icons.auto_awesome_rounded,
  MissionLane.quiet => Icons.horizontal_rule_rounded,
};

/// Localized, sentence-case label for a Mission Control lane.
String missionLaneLabel(BuildContext context, MissionLane lane) {
  final l10n = context.l10n;
  return switch (lane) {
    MissionLane.blocked => l10n.missionControlStatBlocked,
    MissionLane.unread => l10n.missionControlStatUnread,
    MissionLane.live => l10n.missionControlStatWorking,
    MissionLane.quiet => l10n.missionControlStatIdle,
  };
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
    name = name.substring(at + 1);
  }
  final parts = name.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.length >= 3 && name.length > 14) {
    return parts.take(2).join('-');
  }
  return name;
}
