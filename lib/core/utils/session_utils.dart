import '../models/session.dart';

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

/// Formats a date into a localized date header string.
/// Returns "Today", "Yesterday", or "X days ago" based on the date.
String formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(today.millisecondsSinceEpoch - 24 * 60 * 60 * 1000);
  final sessionDate =
      DateTime(date.year, date.month, date.day);

  if (sessionDate.millisecondsSinceEpoch == today.millisecondsSinceEpoch) {
    return 'Today';
  } else if (sessionDate.millisecondsSinceEpoch ==
      yesterday.millisecondsSinceEpoch) {
    return 'Yesterday';
  } else {
    final diffTime = today.millisecondsSinceEpoch - sessionDate.millisecondsSinceEpoch;
    final diffDays = (diffTime / (1000 * 60 * 60 * 24)).floor();
    return '$diffDays days ago';
  }
}

/// Groups sessions by date and creates a flat list with date headers.
/// Sessions are sorted by updatedAt in descending order (most recent first).
///
/// Returns a list of [SessionHistoryItem] containing alternating date headers
/// and session items.
List<SessionHistoryItem> groupSessionsByDate(List<Session> sessions) {
  if (sessions.isEmpty) {
    return [];
  }

  final sortedSessions = [...sessions]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final items = <SessionHistoryItem>[];
  Session? currentDateSession;
  String? currentDateString;
  final currentGroup = <Session>[];

  for (final session in sortedSessions) {
    final sessionDate = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    final dateString = sessionDate.toIso8601String().split('T').first;

    if (currentDateString != dateString) {
      // Process previous group
      if (currentGroup.isNotEmpty) {
        items.add(SessionHistoryDateHeader(
            formatDateHeader(DateTime.parse(currentDateString!))));
        for (final sess in currentGroup) {
          items.add(SessionHistorySession(sess));
        }
      }

      // Start new group
      currentDateString = dateString;
      currentGroup.clear();
      currentGroup.add(session);
    } else {
      currentGroup.add(session);
    }
  }

  // Process final group
  if (currentGroup.isNotEmpty) {
    items.add(SessionHistoryDateHeader(
        formatDateHeader(DateTime.parse(currentDateString!))));
    for (final sess in currentGroup) {
      items.add(SessionHistorySession(sess));
    }
  }

  return items;
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
  final normalizedHome = homeDir.endsWith('/') ? homeDir.substring(0, homeDir.length - 1) : homeDir;
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
    // Format as date
    final date = DateTime.fromMillisecondsSinceEpoch(activeAt);
    final nowYear = DateTime.now().year;
    final options = <String, dynamic>{
      'month': 'short',
      'day': 'numeric',
    };
    if (date.year != nowYear) {
      options['year'] = 'numeric';
    }
    return '${date.month}/${date.day}/${date.year}';
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

  // Format as date
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final nowYear = DateTime.now().year;
  if (date.year == nowYear) {
    return '${date.month}/${date.day}';
  }
  return '${date.month}/${date.day}/${date.year}';
}
