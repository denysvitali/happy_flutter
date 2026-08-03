import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/machine.dart';
import '../models/session.dart';
import 'utils.dart';

// Re-export the canonical formatTimestamp from utils.dart so that existing
// consumers of session_utils.dart continue to work without modification.
export 'utils.dart' show formatTimestamp;

/// Formats a date for display as a date header.
/// Returns "Today", "Yesterday", or "X days ago" (localized).
String formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final sessionDate = DateTime(date.year, date.month, date.day);

  if (sessionDate.isAtSameMomentAs(today)) {
    return 'Today';
  } else if (sessionDate.isAtSameMomentAs(yesterday)) {
    return 'Yesterday';
  } else {
    final diffTime = today.difference(sessionDate);
    final diffDays = diffTime.inDays;
    return '$diffDays days ago';
  }
}

/// Date grouping categories for session history.
enum DateGroup { today, yesterday, thisWeek, thisMonth, older }

/// Groups sessions into date-based categories.
///
/// Categories: "Today", "Yesterday", "This Week",
/// "This Month", "Older".
Map<DateGroup, List<Session>> groupSessionsByDateCategory(
  List<Session> sessions, {
  int? Function(String sessionId)? getLastMessageTimestamp,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month);

  final groups = <DateGroup, List<Session>>{
    DateGroup.today: [],
    DateGroup.yesterday: [],
    DateGroup.thisWeek: [],
    DateGroup.thisMonth: [],
    DateGroup.older: [],
  };

  for (final session in sessions) {
    // Use the same effective last-activity time the card displays so the
    // group header (Today/Yesterday/...) matches the timestamp on the
    // card. Falling back to session.updatedAt alone caused sessions to
    // land in the wrong group when the local message cache or
    // server-provided lastMessage was newer.
    final effectiveTs = getLastMessageTimestamp?.call(session.id) ??
        session.lastMessageAt ??
        session.updatedAt;
    final sessionDate = DateTime.fromMillisecondsSinceEpoch(effectiveTs);
    final dateOnly = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );

    if (dateOnly.isAtSameMomentAs(today)) {
      groups[DateGroup.today]!.add(session);
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      groups[DateGroup.yesterday]!.add(session);
    } else if (dateOnly.isAfter(weekAgo)) {
      groups[DateGroup.thisWeek]!.add(session);
    } else if (!dateOnly.isBefore(monthStart)) {
      groups[DateGroup.thisMonth]!.add(session);
    } else {
      groups[DateGroup.older]!.add(session);
    }
  }

  // Remove empty groups and sort within each
  // group (newest first).
  groups
    ..removeWhere((_, sessions) => sessions.isEmpty)
    ..forEach((_, sessions) {
      sessions.sort((a, b) {
        final aTs = getLastMessageTimestamp != null
            ? getLastMessageTimestamp(a.id) ?? a.lastMessageAt ?? a.updatedAt
            : a.lastMessageAt ?? a.updatedAt;
        final bTs = getLastMessageTimestamp != null
            ? getLastMessageTimestamp(b.id) ?? b.lastMessageAt ?? b.updatedAt
            : b.lastMessageAt ?? b.updatedAt;
        return bTs.compareTo(aTs);
      });
    });

  return groups;
}

/// Returns the display name for a date group.
/// Uses a callback for localization to avoid
/// importing generated l10n.
String getDateGroupHeader(
  DateGroup group, {
  required String Function(DateGroup) localize,
}) {
  return localize(group);
}

/// Ordered list of [DateGroup] values for display.
const dateGroupOrder = <DateGroup>[
  DateGroup.today,
  DateGroup.yesterday,
  DateGroup.thisWeek,
  DateGroup.thisMonth,
  DateGroup.older,
];

/// Session history item types for grouped list display
sealed class SessionHistoryItem {
  const SessionHistoryItem();
}

class SessionHistoryDateHeader extends SessionHistoryItem {
  const SessionHistoryDateHeader(this.date);
  final String date;
}

class SessionHistorySession extends SessionHistoryItem {
  const SessionHistorySession(this.session);
  final Session session;
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

  for (final group in dateGroupOrder) {
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

/// Groups sessions by exact date and creates a flat list with date headers.
/// Sessions are sorted by updatedAt in descending order (most recent first).
///
/// Returns a list of [SessionHistoryItem] containing alternating date headers
/// and session items, similar to the React Native implementation.
List<SessionHistoryItem> groupSessionsByExactDate(List<Session> sessions) {
  if (sessions.isEmpty) {
    return [];
  }

  // Sort sessions by updatedAt descending
  final sortedSessions = List<Session>.from(sessions)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final items = <SessionHistoryItem>[];
  var currentDateGroup = <Session>[];
  String? currentDateString;

  for (final session in sortedSessions) {
    final sessionDate = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    final dateString =
        '${sessionDate.year}-'
        '${sessionDate.month.toString().padLeft(2, '0')}-'
        '${sessionDate.day.toString().padLeft(2, '0')}';

    if (currentDateString != dateString) {
      // Process previous group
      if (currentDateGroup.isNotEmpty) {
        items.add(
          SessionHistoryDateHeader(
            formatDateHeader(DateTime.parse(currentDateString!)),
          ),
        );
        for (final sess in currentDateGroup) {
          items.add(SessionHistorySession(sess));
        }
      }

      // Start new group
      currentDateString = dateString;
      currentDateGroup = [session];
    } else {
      currentDateGroup.add(session);
    }
  }

  // Process final group
  if (currentDateGroup.isNotEmpty) {
    items.add(
      SessionHistoryDateHeader(
        formatDateHeader(DateTime.parse(currentDateString!)),
      ),
    );
    for (final sess in currentDateGroup) {
      items.add(SessionHistorySession(sess));
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
  int? Function(String sessionId)? getLastMessageTimestamp,
}) {
  if (sessions.isEmpty) {
    return [];
  }

  final grouped = groupSessionsByDateCategory(
    sessions,
    getLastMessageTimestamp: getLastMessageTimestamp,
  );

  String defaultLocalize(DateGroup group) {
    return switch (group) {
      DateGroup.today => 'Today',
      DateGroup.yesterday => 'Yesterday',
      DateGroup.thisWeek => 'This Week',
      DateGroup.thisMonth => 'This Month',
      DateGroup.older => 'Older',
    };
  }

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
    var lastSegment = segments.isNotEmpty ? segments.last : null;
    if (lastSegment == null) {
      return 'Unknown';
    }
    // Remove hash from workspace-xxx-*** names
    if (lastSegment.startsWith('workspace-')) {
      final parts = lastSegment.split('-');
      if (parts.length > 2) {
        lastSegment = parts.sublist(0, 2).join('-');
      }
    }
    return lastSegment;
  }
  return 'Unknown';
}

/// Returns stable display names, suffixing only names that occur more than
/// once in [sessions].
///
/// Folder-centric views commonly contain several sessions whose fallback name
/// is the folder itself. A short session id keeps those rows distinguishable
/// without changing unique summaries or names.
Map<String, String> getDisambiguatedSessionNames(Iterable<Session> sessions) {
  final sessionList = sessions.toList(growable: false);
  final baseNames = <String, String>{
    for (final session in sessionList) session.id: getSessionName(session),
  };
  final occurrences = <String, int>{};
  for (final name in baseNames.values) {
    occurrences[name] = (occurrences[name] ?? 0) + 1;
  }

  return {
    for (final session in sessionList)
      session.id: occurrences[baseNames[session.id]]! > 1
          ? '${baseNames[session.id]} · ${_shortSessionId(session.id)}'
          : baseNames[session.id]!,
  };
}

String _shortSessionId(String id) {
  const length = 6;
  return id.length <= length ? id : id.substring(0, length);
}

/// Generates a deterministic avatar ID from the session ID.
/// Each session gets its own unique avatar appearance.
String getSessionAvatarId(Session session) {
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
      return formatPathRelativeToHome(path, homeDir: session.metadata!.homeDir);
    }
  }
  return 'Unknown';
}

/// Checks if a session is currently online based on the real-time presence
/// field.
bool isSessionOnline(Session session) {
  return session.presence == 'online';
}

/// Checks if a session should be shown in the active sessions group.
///
/// Prefers real-time [Session.presence] when available, but falls back to
/// persisted [Session.active] so sessions still appear after app relaunch or
/// when ephemeral activity events have not arrived yet.
///
/// Sessions whose last [Session.activeAt] is older than [sessionIdleAfterMs]
/// are demoted to the inactive group even if `presence == 'online'` or
/// `active == true`, so long-running agents that haven't done anything for
/// hours stop cluttering the active list.
bool isSessionActive(Session session) {
  // A live agent process wins over a stale `archived` flag. The CLI flips
  // archived=true on clean exit; on respawn the daemon flips it back, but
  // the unarchive can lose to the next clean-exit archive when sessions
  // churn. Without this check the chat header shows "Online" (it trusts
  // lifecycleState=running) while the list keeps the session in the
  // archived bucket — the visible discrepancy users hit.
  if (_hasRecentRunningLifecycle(session)) return true;
  if (session.archived) return false;
  if (isSessionIdle(session)) return false;
  return session.presence == 'online' || session.active;
}

const int _sessionLifecycleRecentMs = 120000;

bool _hasRecentRunningLifecycle(Session session) {
  final lc = session.effectiveLifecycleState;
  if (lc != 'running' && lc != 'starting') return false;
  final since = session.metadata?.lifecycleStateSince;
  if (since == null) return false;
  return DateTime.now().millisecondsSinceEpoch - since <
      _sessionLifecycleRecentMs;
}

/// How long a session can sit without activity before it is treated as idle
/// and pushed into the inactive list, regardless of `presence`/`active`.
const int sessionIdleAfterMs = 6 * 60 * 60 * 1000;

/// Whether the session has been quiet long enough to be considered idle.
///
/// A non-positive [Session.activeAt] is treated as "no signal" and never
/// classified as idle — that prevents brand-new or partially-hydrated
/// sessions from disappearing the moment they show up.
bool isSessionIdle(Session session) {
  final activeAt = session.activeAt;
  if (activeAt <= 0) return false;
  return DateTime.now().millisecondsSinceEpoch - activeAt > sessionIdleAfterMs;
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
String formatLastSeen(
  int activeAt, {
  bool isActive = false,
  String locale = 'en',
}) {
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
    // Format as date using intl. Locale data may be uninitialized (intl
    // throws LocaleDataException) or the tag unknown (ArgumentError); a
    // last-seen string is never worth taking the caller down for.
    final date = DateTime.fromMillisecondsSinceEpoch(activeAt);
    try {
      return DateFormat.yMMMd(locale).format(date);
    } catch (_) {
      return formatShortDate(date);
    }
  }
}

// ─── Folder grouping ─────────────────────────────────────────────────────────

/// Canonical folder key for a session: `'${machineId}:${path}'`.
///
/// Must stay in sync with the inline key logic used when building
/// [SessionFolderGroup] and [SessionFolderHeader], so that selection scope
/// (in folder view) matches the sessions rendered in the list.
String sessionFolderKey(Session session) {
  final machineId = session.metadata?.machineId ?? '';
  final path = session.metadata?.path ?? '';
  return '$machineId:$path';
}

/// A discriminated union of items in a folder-grouped inactive session list.
sealed class SessionFolderItem {
  const SessionFolderItem();
}

/// Header for a folder group (machine + path).
class SessionFolderHeader extends SessionFolderItem {
  const SessionFolderHeader({
    required this.displayPath,
    required this.machineName,
    required this.sessionCount,
    required this.folderKey,
    this.latestActivityAt = 0,
    this.activeSessionCount = 0,
    this.inactiveSessionCount = 0,
    this.unreadCount = 0,
  });

  /// The path to display (with ~ substitution for home directory).
  final String displayPath;

  /// The display name of the machine.
  final String machineName;

  /// Number of sessions in this folder group.
  final int sessionCount;

  /// The unique key for this folder group ('machineId:path').
  final String folderKey;

  /// Most recent activity timestamp across all sessions in the folder group.
  final int latestActivityAt;

  /// Number of active sessions in this folder group.
  final int activeSessionCount;

  /// Number of inactive sessions in this folder group.
  final int inactiveSessionCount;

  /// Aggregated unread count across all sessions in the folder group.
  final int unreadCount;

  bool get hasUpdates => unreadCount > 0;
}

/// An individual session entry within a folder group.
class SessionFolderEntry extends SessionFolderItem {
  const SessionFolderEntry({
    required this.session,
    required this.isFirst,
    required this.isLast,
    required this.isSingle,
  });

  /// The session.
  final Session session;

  /// Whether this is the first session in the folder group.
  final bool isFirst;

  /// Whether this is the last session in the folder group.
  final bool isLast;

  /// Whether this is the only session in the folder group.
  final bool isSingle;
}

class SessionFolderGroup {
  const SessionFolderGroup({
    required this.header,
    required this.activeSessions,
    required this.inactiveSessions,
  });

  final SessionFolderHeader header;
  final List<Session> activeSessions;
  final List<Session> inactiveSessions;
}

/// Groups inactive sessions by their working directory path and machine.
///
/// Returns a flat list of [SessionFolderItem] where each folder group starts
/// with a [SessionFolderHeader] followed by [SessionFolderEntry] items.
/// Groups are sorted by the most recently active session descending.
List<SessionFolderItem> groupSessionsByFolder(
  List<Session> sessions,
  Map<String, Machine> machines, {
  int? Function(String sessionId)? getLastMessageTimestamp,
}) {
  if (sessions.isEmpty) return [];

  // Group by (machineId:path) key, preserving insertion order.
  final groups = <String, List<Session>>{};
  for (final s in sessions) {
    groups.putIfAbsent(sessionFolderKey(s), () => []).add(s);
  }

  // Sort groups by most recently active session descending.
  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      int ts(Session s) => getLastMessageTimestamp != null
          ? getLastMessageTimestamp(s.id) ?? s.lastMessageAt ?? s.updatedAt
          : s.lastMessageAt ?? s.updatedAt;
      final aLatest = groups[a]!.map(ts).reduce(math.max);
      final bLatest = groups[b]!.map(ts).reduce(math.max);
      return bLatest.compareTo(aLatest);
    });

  // Sort sessions within each group by last activity descending.
  for (final key in sortedKeys) {
    groups[key]!.sort((a, b) {
      final aTs = getLastMessageTimestamp != null
          ? getLastMessageTimestamp(a.id) ?? a.lastMessageAt ?? a.updatedAt
          : a.lastMessageAt ?? a.updatedAt;
      final bTs = getLastMessageTimestamp != null
          ? getLastMessageTimestamp(b.id) ?? b.lastMessageAt ?? b.updatedAt
          : b.lastMessageAt ?? b.updatedAt;
      return bTs.compareTo(aTs);
    });
  }

  final items = <SessionFolderItem>[];
  for (final key in sortedKeys) {
    final groupSessions = groups[key]!;
    final first = groupSessions.first;
    final machineId = first.metadata?.machineId ?? '';
    final machine = machines[machineId];
    final machineName =
        machine?.metadata?.displayName ??
        machine?.metadata?.host ??
        first.metadata?.host ??
        'Unknown';

    // Display path: substitute ~ for homeDir (uses normalised helper).
    final rawPath = first.metadata?.path ?? '';
    final homeDir = first.metadata?.homeDir;
    final displayPath = rawPath.isEmpty
        ? 'Unknown'
        : formatPathRelativeToHome(rawPath, homeDir: homeDir);
    final latestActivityAt = groupSessions
        .map(
          (session) => getLastMessageTimestamp != null
              ? getLastMessageTimestamp(session.id) ??
                    session.lastMessageAt ??
                    session.updatedAt
              : session.lastMessageAt ?? session.updatedAt,
        )
        .reduce(math.max);

    items.add(
      SessionFolderHeader(
        displayPath: displayPath,
        machineName: machineName,
        sessionCount: groupSessions.length,
        folderKey: key,
        latestActivityAt: latestActivityAt,
      ),
    );

    for (var i = 0; i < groupSessions.length; i++) {
      items.add(
        SessionFolderEntry(
          session: groupSessions[i],
          isFirst: i == 0,
          isLast: i == groupSessions.length - 1,
          isSingle: groupSessions.length == 1,
        ),
      );
    }
  }
  return items;
}

/// Groups all sessions by their working directory path and machine.
///
/// Sessions are split into active and inactive lists within each folder group.
/// Groups are ordered by the most recent activity across either list.
List<SessionFolderGroup> groupAllSessionsByFolder(
  List<Session> activeSessions,
  List<Session> inactiveSessions,
  Map<String, Machine> machines, {
  int? Function(String sessionId)? getLastMessageTimestamp,
  int Function(String sessionId)? getUnreadCount,
}) {
  if (activeSessions.isEmpty && inactiveSessions.isEmpty) {
    return const [];
  }

  final groupedActive = <String, List<Session>>{};
  final groupedInactive = <String, List<Session>>{};

  for (final session in activeSessions) {
    groupedActive.putIfAbsent(sessionFolderKey(session), () => []).add(session);
  }
  for (final session in inactiveSessions) {
    groupedInactive
        .putIfAbsent(sessionFolderKey(session), () => [])
        .add(session);
  }

  int activityTs(Session session) => getLastMessageTimestamp != null
      ? getLastMessageTimestamp(session.id) ??
            session.lastMessageAt ??
            session.updatedAt
      : session.lastMessageAt ?? session.updatedAt;

  final keys = {...groupedActive.keys, ...groupedInactive.keys}.toList()
    ..sort((a, b) {
      final aSessions = [...?groupedActive[a], ...?groupedInactive[a]];
      final bSessions = [...?groupedActive[b], ...?groupedInactive[b]];
      final aLatest = aSessions.map(activityTs).reduce(math.max);
      final bLatest = bSessions.map(activityTs).reduce(math.max);
      return bLatest.compareTo(aLatest);
    });

  List<Session> sortActive(List<Session> sessions) {
    final sorted = List<Session>.from(sessions)
      ..sort((a, b) {
        final aOnline = a.presence == 'online' ? 0 : 1;
        final bOnline = b.presence == 'online' ? 0 : 1;
        if (aOnline != bOnline) {
          return aOnline.compareTo(bOnline);
        }
        return activityTs(b).compareTo(activityTs(a));
      });
    return sorted;
  }

  List<Session> sortInactive(List<Session> sessions) {
    final sorted = List<Session>.from(sessions)
      ..sort((a, b) => activityTs(b).compareTo(activityTs(a)));
    return sorted;
  }

  return [
    for (final key in keys)
      () {
        final active = sortActive(groupedActive[key] ?? const []);
        final inactive = sortInactive(groupedInactive[key] ?? const []);
        final first = [...active, ...inactive].first;
        final machineId = first.metadata?.machineId ?? '';
        final machine = machines[machineId];
        final machineName =
            machine?.metadata?.displayName ??
            machine?.metadata?.host ??
            first.metadata?.host ??
            'Unknown';
        final rawPath = first.metadata?.path ?? '';
        final homeDir = first.metadata?.homeDir;
        final displayPath = rawPath.isEmpty
            ? 'Unknown'
            : formatPathRelativeToHome(rawPath, homeDir: homeDir);
        final unread = getUnreadCount == null
            ? 0
            : active
                  .map((session) => getUnreadCount(session.id))
                  .fold<int>(0, (sum, count) => sum + count);

        return SessionFolderGroup(
          header: SessionFolderHeader(
            displayPath: displayPath,
            machineName: machineName,
            sessionCount: active.length + inactive.length,
            folderKey: key,
            latestActivityAt: [
              ...active,
              ...inactive,
            ].map(activityTs).reduce(math.max),
            activeSessionCount: active.length,
            inactiveSessionCount: inactive.length,
            unreadCount: unread,
          ),
          activeSessions: active,
          inactiveSessions: inactive,
        );
      }(),
  ];
}
