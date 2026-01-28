import 'package:intl/intl.dart';

import '../models/session.dart';

/// Date grouping categories for session history
enum DateGroup {
  today,
  yesterday,
  lastSevenDays,
  older,
}

/// Groups sessions into date-based categories.
/// Categories: "Today", "Yesterday", "Last 7 Days", "Older"
Map<DateGroup, List<Session>> groupSessionsByDateCategory(
  List<Session> sessions,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final sevenDaysAgo = today.subtract(const Duration(days: 7));

  final groups = <DateGroup, List<Session>>{
    DateGroup.today: [],
    DateGroup.yesterday: [],
    DateGroup.lastSevenDays: [],
    DateGroup.older: [],
  };

  for (final session in sessions) {
    final sessionDate = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    final dateOnly = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );

    if (dateOnly.isAtSameMomentAs(today)) {
      groups[DateGroup.today]!.add(session);
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      groups[DateGroup.yesterday]!.add(session);
    } else if (dateOnly.isAfter(sevenDaysAgo)) {
      groups[DateGroup.lastSevenDays]!.add(session);
    } else {
      groups[DateGroup.older]!.add(session);
    }
  }

  // Remove empty groups and sort sessions within each group (newest first)
  groups.removeWhere((_, sessions) => sessions.isEmpty);
  groups.forEach((_, sessions) {
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  });

  return groups;
}

/// Returns the display name for a date group.
/// Uses a callback for localization to avoid importing generated l10n.
String getDateGroupHeader(
  DateGroup group, {
  required String Function(DateGroup) localize,
}) {
  return localize(group);
}

/// Session history item types for grouped list display
sealed class SessionHistoryItem {
  const SessionHistoryItem();
}

class SessionHistoryDateHeader extends SessionHistoryItem {
  final String date;
  const SessionHistoryDateHeader(this.date);
}

class SessionHistorySession extends SessionHistoryItem {
  final Session session;
  const SessionHistorySession(this.session);
}

/// Creates a flat list of [SessionHistoryItem] from date-grouped sessions.
/// Sessions are sorted by updatedAt in descending order (most recent first).
///
/// The [localize] callback is used to get localized date group headers.
///
/// Returns a list of [SessionHistoryItem] containing alternating date headers
/// and session items.
List<SessionHistoryItem> createSessionHistoryList(
  Map<DateGroup, List<Session>> groupedSessions, {
  required String Function(DateGroup) localize,
}) {
  final items = <SessionHistoryItem>[];
  final order = <DateGroup>[
    DateGroup.today,
    DateGroup.yesterday,
    DateGroup.lastSevenDays,
    DateGroup.older,
  ];

  for (final group in order) {
    final sessions = groupedSessions[group];
    if (sessions == null || sessions.isEmpty) {
      continue;
    }

    items.add(SessionHistoryDateHeader(localize(group)));

    for (final session in sessions) {
      items.add(SessionHistorySession(session));
    }
  }

  return items;
}

/// Groups sessions by date and creates a flat list with date headers.
/// Sessions are sorted by updatedAt in descending order (most recent first).
///
/// The [localize] callback is used to get localized date group headers.
/// If not provided, uses default English strings.
///
/// Returns a list of [SessionHistoryItem] containing alternating date headers
/// and session items.
List<SessionHistoryItem> groupSessionsByDate(
  List<Session> sessions, {
  String Function(DateGroup)? localize,
}) {
  if (sessions.isEmpty) {
    return [];
  }

  final grouped = groupSessionsByDateCategory(sessions);

  final defaultLocalize = (DateGroup group) {
    return switch (group) {
      DateGroup.today => 'Today',
      DateGroup.yesterday => 'Yesterday',
      DateGroup.lastSevenDays => 'Last 7 Days',
      DateGroup.older => 'Older',
    };
  };

  return createSessionHistoryList(
    grouped,
    localize: localize ?? defaultLocalize,
  );
}

/// Extracts a display name from a session's metadata path.
/// Returns the last segment of the path, or 'Unknown' if no path is available.
String getSessionName(Session session) {
  if (session.metadata?.summary != null) {
    return session.metadata!.summary!.text;
  } else if (session.metadata != null) {
    final path = session.metadata!.path ?? '';
    final segments = path.split('/').where((e) => e.isNotEmpty);
    final lastSegment = segments.isNotEmpty ? segments.last : null;
    if (lastSegment == null) {
      return 'Unknown';
    }
    return lastSegment;
  }
  return 'Unknown';
}

/// Generates a deterministic avatar ID from machine ID and path.
/// This ensures the same machine + path combination always gets the same avatar.
String getSessionAvatarId(Session session) {
  if (session.metadata?.machineId != null && session.metadata?.path != null) {
    // Combine machine ID and path for a unique, deterministic avatar
    return '${session.metadata!.machineId}:${session.metadata!.path}';
  }
  // Fallback to session ID if metadata is missing
  return session.id;
}

/// Formats a path relative to home directory if possible.
/// If the path starts with the home directory, replaces it with ~
/// Otherwise returns the full path.
String formatPathRelativeToHome(String path, {String? homeDir}) {
  if (homeDir == null) return path;

  // Normalize paths to handle trailing slashes
  final normalizedHome = homeDir.endsWith('/')
      ? homeDir.substring(0, homeDir.length - 1)
      : homeDir;
  final normalizedPath = path;

  // Check if path starts with home directory
  if (normalizedPath.startsWith(normalizedHome)) {
    // Replace home directory with ~
    final relativePath = normalizedPath.substring(normalizedHome.length);
    // Add ~ and ensure there's a / after it if needed
    if (relativePath.startsWith('/')) {
      return '~$relativePath';
    } else if (relativePath.isEmpty) {
      return '~';
    } else {
      return '~/$relativePath';
    }
  }

  return path;
}

/// Returns the session path for the subtitle display.
String getSessionSubtitle(Session session) {
  if (session.metadata != null) {
    final path = session.metadata!.path;
    if (path != null) {
      return formatPathRelativeToHome(
        path,
        homeDir: session.metadata!.homeDir,
      );
    }
  }
  return 'Unknown';
}

/// Checks if a session is currently online based on the active flag.
bool isSessionOnline(Session session) {
  return session.active;
}

/// Checks if a session should be shown in the active sessions group.
bool isSessionActive(Session session) {
  return session.active;
}

/// Formats OS platform string into a more readable format.
String formatOSPlatform(String? platform) {
  if (platform == null) return '';

  final osMap = <String, String>{
    'darwin': 'macOS',
    'win32': 'Windows',
    'linux': 'Linux',
    'android': 'Android',
    'ios': 'iOS',
    'aix': 'AIX',
    'freebsd': 'FreeBSD',
    'openbsd': 'OpenBSD',
    'sunos': 'SunOS',
  };

  return osMap[platform.toLowerCase()] ?? platform;
}

/// Formats the last seen time of a session into a human-readable relative time.
String formatLastSeen(int activeAt, {bool isActive = false}) {
  if (isActive) {
    return 'Active now';
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  final diffMs = now - activeAt;
  final diffSeconds = (diffMs / 1000).floor();
  final diffMinutes = (diffSeconds / 60).floor();
  final diffHours = (diffMinutes / 60).floor();
  final diffDays = (diffHours / 24).floor();

  if (diffSeconds < 60) {
    return 'Just now';
  } else if (diffMinutes < 60) {
    return '$diffMinutes minutes ago';
  } else if (diffHours < 24) {
    return '$diffHours hours ago';
  } else if (diffDays < 7) {
    return '$diffDays days ago';
  } else {
    // Format as date using intl
    final date = DateTime.fromMillisecondsSinceEpoch(activeAt);
    final formatter = DateFormat.yMMMd();
    return formatter.format(date);
  }
}

/// Formats a timestamp into a human-readable relative time string.
String formatTimestamp(int timestamp, {bool relative = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final diffMs = now - timestamp;
  final diffSeconds = (diffMs / 1000).floor();
  final diffMinutes = (diffSeconds / 60).floor();
  final diffHours = (diffMinutes / 60).floor();
  final diffDays = (diffHours / 24).floor();

  if (relative) {
    if (diffSeconds < 60) {
      return 'Just now';
    } else if (diffMinutes < 60) {
      return '$diffMinutes min ago';
    } else if (diffHours < 24) {
      return '$diffHours hr ago';
    } else if (diffDays < 7) {
      return '$diffDays days ago';
    }
  }

  // Format as date using intl
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final nowYear = DateTime.now().year;
  final formatter = DateFormat(nowYear == date.year ? 'MMM d' : 'MMM d, yyyy');
  return formatter.format(date);
}
