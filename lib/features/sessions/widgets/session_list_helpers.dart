import '../../../core/models/session.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/opentelemetry_service.dart';
import '../../../core/utils/performance_buckets.dart';
import '../../../core/utils/session_utils.dart';
import 'session_headers.dart';

// ─── Selection state ──────────────────────────────────

/// Immutable selection state shared between the parent
/// screen (AppBar) and the list content via a
/// [ValueNotifier].
class SelectionState {
  const SelectionState({
    this.isActive = false,
    this.selectedIds = const {},
    this.isBatchDeleting = false,
  });

  final bool isActive;
  final Set<String> selectedIds;
  final bool isBatchDeleting;

  SelectionState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    bool? isBatchDeleting,
  }) {
    return SelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      isBatchDeleting: isBatchDeleting ?? this.isBatchDeleting,
    );
  }
}

/// Whether the sessions collection is the visible route.
///
/// The root route is named `home`; `/sessions` is named `sessions`. A null
/// route is treated as visible during startup, before the route observer has
/// received its first callback.
bool isSessionsCollectionRoute(String? route) {
  return route == null || route == 'home' || route == 'sessions';
}

// ─── Sorted session cache ─────────────────────────────

/// Memoized result of sorting sessions into active and
/// inactive lists.
class SortedSessions {
  const SortedSessions({
    required this.active,
    required this.inactive,
    required this.signature,
  });
  final List<Session> active;
  final List<Session> inactive;
  final int signature;
}

/// Compute sorted active/inactive lists, only if
/// [sessions] changed.
///
/// Sessions in [optimisticallyArchivedIds] are excluded
/// from the active list to prevent them from reappearing
/// during server replication lag.
///
/// Sessions are sorted by last message timestamp when
/// available, falling back to [Session.activeAt] (active)
/// or [Session.updatedAt] (inactive).
SortedSessions computeSortedSessions(
  Map<String, Session> sessions, {
  required SortedSessions? previous,
  required Map<String, Session>? lastSessions,
  required String? lastSearchQuery,
  required Set<String> optimisticallyArchivedIds,
  required int? Function(String sessionId) getLastMessageTimestamp,
  String searchQuery = '',
  Set<String>? lastOptimisticallyArchivedIds,
  Object? timestampRevision,
  Object? lastTimestampRevision,
}) {
  final stopwatch = Stopwatch()..start();
  if (previous != null &&
      identical(sessions, lastSessions) &&
      searchQuery == lastSearchQuery &&
      identical(optimisticallyArchivedIds, lastOptimisticallyArchivedIds) &&
      identical(timestampRevision, lastTimestampRevision)) {
    stopwatch.stop();
    _recordSortedSessionsDuration(
      stopwatch.elapsed,
      sessionCount: sessions.length,
      cacheHit: true,
      hasQuery: searchQuery.trim().isNotEmpty,
    );
    return previous;
  }
  final signature = _computeSortedSessionsSignature(
    sessions,
    optimisticallyArchivedIds: optimisticallyArchivedIds,
    getLastMessageTimestamp: getLastMessageTimestamp,
    searchQuery: searchQuery,
  );

  if (previous != null && previous.signature == signature) {
    stopwatch.stop();
    _recordSortedSessionsDuration(
      stopwatch.elapsed,
      sessionCount: sessions.length,
      cacheHit: true,
      hasQuery: searchQuery.trim().isNotEmpty,
    );
    return previous;
  }

  final query = searchQuery.toLowerCase().trim();
  var sessionList = sessions.values;
  if (query.isNotEmpty) {
    sessionList = sessionList.where((s) {
      final name = (s.metadata?.name ?? '').toLowerCase();
      final path = (s.metadata?.path ?? '').toLowerCase();
      final summary = (s.metadata?.summary?.text ?? '').toLowerCase();
      return name.contains(query) ||
          path.contains(query) ||
          summary.contains(query);
    });
  }

  final active = <Session>[];
  final inactive = <Session>[];
  for (final s in sessionList) {
    if (optimisticallyArchivedIds.contains(s.id)) {
      continue;
    }
    if (isSessionActive(s)) {
      active.add(s);
    } else {
      inactive.add(s);
    }
  }
  active.sort((a, b) {
    final aOnline = a.presence == 'online' ? 0 : 1;
    final bOnline = b.presence == 'online' ? 0 : 1;
    if (aOnline != bOnline) return aOnline.compareTo(bOnline);
    final aTs = getLastMessageTimestamp(a.id) ?? a.lastMessageAt ?? a.activeAt;
    final bTs = getLastMessageTimestamp(b.id) ?? b.lastMessageAt ?? b.activeAt;
    return bTs.compareTo(aTs);
  });
  inactive.sort((a, b) {
    final aTs = getLastMessageTimestamp(a.id) ?? a.lastMessageAt ?? a.updatedAt;
    final bTs = getLastMessageTimestamp(b.id) ?? b.lastMessageAt ?? b.updatedAt;
    return bTs.compareTo(aTs);
  });
  final result = SortedSessions(
    active: active,
    inactive: inactive,
    signature: signature,
  );
  stopwatch.stop();
  _recordSortedSessionsDuration(
    stopwatch.elapsed,
    sessionCount: sessions.length,
    cacheHit: false,
    hasQuery: query.isNotEmpty,
  );
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (stopwatch.elapsedMilliseconds >= 16 &&
      nowMs - _lastSlowSortLogAtMs >= 30000) {
    _lastSlowSortLogAtMs = nowMs;
    logger.warning(
      '[Perf] computeSortedSessions '
      'count=${sessions.length} '
      'query="${searchQuery.trim()}" '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
  }
  return result;
}

int _lastSlowSortLogAtMs = 0;

void _recordSortedSessionsDuration(
  Duration duration, {
  required int sessionCount,
  required bool cacheHit,
  required bool hasQuery,
}) {
  OpenTelemetryService().recordDuration(
    'app.sessions.sort',
    duration,
    attributes: {
      'session_count_bucket': collectionSizeBucket(sessionCount),
      'cache_hit': cacheHit,
      'query_active': hasQuery,
    },
    description: 'Time to filter and sort the sessions collection',
  );
}

int _computeSortedSessionsSignature(
  Map<String, Session> sessions, {
  required Set<String> optimisticallyArchivedIds,
  required int? Function(String sessionId) getLastMessageTimestamp,
  required String searchQuery,
}) {
  var signature = sessions.length ^ searchQuery.hashCode;
  for (final entry in sessions.entries) {
    final session = entry.value;
    signature = Object.hash(
      signature,
      entry.key,
      session.archived,
      session.active,
      session.presence,
      session.activeAt,
      session.updatedAt,
      session.lastMessageAt,
      session.metadata?.name,
      session.metadata?.path,
      session.metadata?.summary?.text,
      getLastMessageTimestamp(session.id),
      optimisticallyArchivedIds.contains(session.id),
      // Capture idleness so a session crossing the idle threshold purely
      // from time passing (no field change) still busts the cache.
      isSessionIdle(session),
    );
  }
  return signature;
}

// ─── Visibility helper ────────────────────────────────

/// Whether to show the inactive/archived sessions section.
bool shouldShowInactiveSessionsSection({
  required bool hideInactive,
  required int activeCount,
  required int inactiveCount,
}) {
  if (inactiveCount == 0) return false;
  if (!hideInactive) return true;
  return activeCount == 0;
}

// ── List item descriptors ─────────────────────────────

/// Enum of list item types rendered in the sessions list.
enum ListItemType {
  sectionHeader,
  projectHeader,
  pathHeader,
  activeSession,
  archiveHeader,
  dateHeader,
  archivedSession,
  folderHeader,
  folderSectionHeader,
  folderEntry,
}

/// Infers a human-readable project name from a file-system path.
///
/// Strategy: strip common prefixes (`~/`, `/home/…/`, `/Users/…/`) and
/// return the first meaningful path segment. Falls back to the full path
/// when the result would be empty.
///
/// Examples:
///   `/home/alice/projects/happy`  →  `happy`
///   `~/work/api`                  →  `work`  (first segment after tilde)
///   `/tmp/scratch`                →  `tmp`
String inferProjectName(String path) {
  var p = path.trim();
  if (p.isEmpty) return path;

  // Normalise tilde to bare segments.
  if (p.startsWith('~/')) p = p.substring(2);

  // Strip leading slash so split doesn't produce an empty first element.
  if (p.startsWith('/')) p = p.substring(1);

  // Strip common home-directory prefixes: home/<user> or Users/<user>.
  final lp = p.toLowerCase();
  if (lp.startsWith('home/') || lp.startsWith('users/')) {
    // Remove 'home/<user>/' or 'users/<user>/'
    final afterPrefix = p.indexOf('/');
    if (afterPrefix != -1) {
      final afterUser = p.indexOf('/', afterPrefix + 1);
      p = afterUser != -1 ? p.substring(afterUser + 1) : '';
    }
  }

  final segments = p.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return path;
  return segments.first;
}

/// Lightweight descriptor for a list item. Widgets are
/// built on demand by
/// [_SessionsListContentState._buildItemWidget].
class ListItem {
  ListItem._raw({
    required this.type,
    required this.staggerIndex,
    this.session,
    this.folderHeader,
    this.title,
    this.pathKey,
    this.projectKey,
    this.sessionCount,
    this.activeSessionCount,
    this.dateKey,
    this.archivedGrouping,
    this.isFirst,
    this.isLast,
    this.isSingle,
  });

  ListItem.sectionHeader(String title, int staggerIndex)
    : this._raw(
        type: ListItemType.sectionHeader,
        staggerIndex: staggerIndex,
        title: title,
      );

  /// Project-level collapsible group header above path headers.
  ListItem.projectHeader(
    String projectKey,
    int sessionCount,
    int activeSessionCount,
    bool _, // isCollapsed — unused at descriptor level
    int staggerIndex,
  ) : this._raw(
        type: ListItemType.projectHeader,
        staggerIndex: staggerIndex,
        projectKey: projectKey,
        sessionCount: sessionCount,
        activeSessionCount: activeSessionCount,
      );

  ListItem.pathHeader(
    String pathKey,
    int sessionCount,
    bool _, // isCollapsed - unused at descriptor level
    int staggerIndex,
  ) : this._raw(
        type: ListItemType.pathHeader,
        staggerIndex: staggerIndex,
        pathKey: pathKey,
        sessionCount: sessionCount,
      );

  ListItem.activeSession(Session session, int staggerIndex)
    : this._raw(
        type: ListItemType.activeSession,
        staggerIndex: staggerIndex,
        session: session,
      );

  ListItem.archiveHeader(
    int sessionCount,
    ArchivedGrouping grouping,
    int staggerIndex,
  ) : this._raw(
        type: ListItemType.archiveHeader,
        staggerIndex: staggerIndex,
        sessionCount: sessionCount,
        archivedGrouping: grouping,
      );

  ListItem.dateHeader(
    String dateKey,
    String title,
    int sessionCount,
    int staggerIndex,
  ) : this._raw(
        type: ListItemType.dateHeader,
        staggerIndex: staggerIndex,
        dateKey: dateKey,
        title: title,
        sessionCount: sessionCount,
      );

  ListItem.archivedSession(
    Session session,
    int staggerIndex, {
    required bool isFirst,
    required bool isLast,
    required bool isSingle,
  }) : this._raw(
         type: ListItemType.archivedSession,
         staggerIndex: staggerIndex,
         session: session,
         isFirst: isFirst,
         isLast: isLast,
         isSingle: isSingle,
       );

  ListItem.folderHeader(SessionFolderHeader header, int staggerIndex)
    : this._raw(
        type: ListItemType.folderHeader,
        staggerIndex: staggerIndex,
        folderHeader: header,
      );

  ListItem.folderEntry(
    Session session,
    int staggerIndex, {
    required bool isFirst,
    required bool isLast,
    required bool isSingle,
  }) : this._raw(
         type: ListItemType.folderEntry,
         staggerIndex: staggerIndex,
         session: session,
         isFirst: isFirst,
         isLast: isLast,
         isSingle: isSingle,
       );

  ListItem.folderSectionHeader(String title, int sessionCount, int staggerIndex)
    : this._raw(
        type: ListItemType.folderSectionHeader,
        staggerIndex: staggerIndex,
        title: title,
        sessionCount: sessionCount,
      );

  final ListItemType type;
  final int staggerIndex;
  final Session? session;
  final SessionFolderHeader? folderHeader;
  final String? title;
  final String? pathKey;
  final String? projectKey;
  final int? sessionCount;
  final int? activeSessionCount;
  final String? dateKey;
  final ArchivedGrouping? archivedGrouping;
  final bool? isFirst;
  final bool? isLast;
  final bool? isSingle;
}
