/// Groups agent-spawned child sessions under their parent for display.
///
/// happy-cli-go writes display-only `parentSessionId` / `rootSessionId` /
/// `nestingDepth` metadata on sessions an agent spawned via
/// `session_spawn`. Nesting is computed over the list a view actually
/// shows, so filtering, search and archive sections stay authoritative:
///
/// - a child nests under its nearest *visible* ancestor (a filtered-out
///   middle generation lifts the grandchild onto the grandparent);
/// - a child with no visible ancestor stays top-level and is reported as
///   an orphan so rows can badge it as a sub-session;
/// - every session appears exactly once — either top-level or under one
///   parent — and the relative order of the input list is preserved.
library;

import 'package:flutter/foundation.dart';

import '../models/session.dart';

/// Upper bound on ancestry walks; guards against malformed cycles.
const int _maxAncestryDepth = 32;

/// Nesting projection of one displayed session list.
@immutable
class SessionNesting {
  const SessionNesting._({
    required this.topLevel,
    required Map<String, List<Session>> children,
    required Set<String> nestedIds,
    required Set<String> orphanIds,
  }) : _children = children,
       _nestedIds = nestedIds,
       _orphanIds = orphanIds;

  /// Builds the projection for [visible], in display order.
  ///
  /// [catalog] (usually every loaded session) resolves ancestors that are
  /// not themselves visible, so a grandchild can still attach to a visible
  /// grandparent. When the list contains no sub-session the input list is
  /// returned unchanged as [topLevel], preserving identity for callers
  /// that cache on it.
  factory SessionNesting.build(
    List<Session> visible, {
    Map<String, Session>? catalog,
  }) {
    if (!visible.any(_hasParent)) {
      return SessionNesting._(
        topLevel: visible,
        children: const {},
        nestedIds: const {},
        orphanIds: const {},
      );
    }
    final visibleIds = {for (final s in visible) s.id};
    final parentOf = <String, String>{};
    for (final session in visible) {
      final parentId = _nearestVisibleAncestor(session, visibleIds, catalog);
      if (parentId != null) parentOf[session.id] = parentId;
    }
    // Malformed metadata can form a loop of visible sessions; promote the
    // first member of each loop so every session still renders once.
    for (final session in visible) {
      final seen = <String>{session.id};
      for (var id = parentOf[session.id]; id != null; id = parentOf[id]) {
        if (!seen.add(id)) {
          parentOf.remove(session.id);
          break;
        }
      }
    }
    final children = <String, List<Session>>{};
    final nestedIds = <String>{};
    final orphanIds = <String>{};
    final topLevel = <Session>[];
    for (final session in visible) {
      final parentId = parentOf[session.id];
      if (parentId == null) {
        topLevel.add(session);
        if (_hasParent(session)) orphanIds.add(session.id);
      } else {
        nestedIds.add(session.id);
        (children[parentId] ??= <Session>[]).add(session);
      }
    }
    return SessionNesting._(
      topLevel: List.unmodifiable(topLevel),
      children: {
        for (final e in children.entries) e.key: List.unmodifiable(e.value),
      },
      nestedIds: nestedIds,
      orphanIds: orphanIds,
    );
  }

  /// A projection without any nesting.
  static const SessionNesting empty = SessionNesting._(
    topLevel: <Session>[],
    children: <String, List<Session>>{},
    nestedIds: <String>{},
    orphanIds: <String>{},
  );

  /// Sessions rendered as their own row; nested children are excluded.
  final List<Session> topLevel;
  final Map<String, List<Session>> _children;
  final Set<String> _nestedIds;
  final Set<String> _orphanIds;

  /// Whether any session in the list nests under another.
  bool get hasNesting => _children.isNotEmpty;

  /// Direct visible children of [sessionId], in display order.
  List<Session> childrenOf(String sessionId) =>
      _children[sessionId] ?? const <Session>[];

  /// Whether [sessionId] renders under a visible ancestor.
  bool isNested(String sessionId) => _nestedIds.contains(sessionId);

  /// Whether [sessionId] is a sub-session whose parent is not shown.
  bool isOrphan(String sessionId) => _orphanIds.contains(sessionId);

  /// Every visible descendant of [sessionId], depth first.
  Iterable<Session> descendantsOf(String sessionId) sync* {
    final seen = <String>{sessionId};
    final stack = [...childrenOf(sessionId).reversed];
    while (stack.isNotEmpty) {
      final next = stack.removeLast();
      if (!seen.add(next.id)) continue;
      yield next;
      stack.addAll(childrenOf(next.id).reversed);
    }
  }

  /// Counts shown on a parent's disclosure.
  SubSessionSummary summaryOf(String sessionId) {
    var total = 0;
    var working = 0;
    var attention = 0;
    for (final s in descendantsOf(sessionId)) {
      total++;
      final online = s.presence == 'online';
      if (online && (s.agentState?.requests?.isNotEmpty ?? false)) {
        attention++;
      } else if (online && s.thinking) {
        working++;
      }
    }
    return SubSessionSummary(
      total: total,
      working: working,
      needsAttention: attention,
    );
  }

  /// Ids of rows currently on screen for [roots]: the roots themselves plus
  /// descendants whose whole ancestor chain [isExpanded].
  Set<String> shownIds(
    Iterable<String> roots,
    bool Function(String parentId) isExpanded,
  ) {
    final ids = <String>{};
    void visit(String id) {
      if (!ids.add(id) || !isExpanded(id)) return;
      for (final child in childrenOf(id)) {
        visit(child.id);
      }
    }

    roots.forEach(visit);
    return ids;
  }

  /// Combines projections of disjoint lists (e.g. active and archived):
  /// top-level rows are concatenated, relations are unioned.
  SessionNesting merge(SessionNesting other) {
    Map<String, List<Session>> children;
    Set<String> nested;
    Set<String> orphans;
    if (!other._hasRelations) {
      (children, nested, orphans) = (_children, _nestedIds, _orphanIds);
    } else if (!_hasRelations) {
      (children, nested, orphans) = (
        other._children,
        other._nestedIds,
        other._orphanIds,
      );
    } else {
      children = {..._children, ...other._children};
      nested = {..._nestedIds, ...other._nestedIds};
      orphans = {..._orphanIds, ...other._orphanIds};
    }
    return SessionNesting._(
      topLevel: other.topLevel.isEmpty
          ? topLevel
          : topLevel.isEmpty
          ? other.topLevel
          : List.unmodifiable([...topLevel, ...other.topLevel]),
      children: children,
      nestedIds: nested,
      orphanIds: orphans,
    );
  }

  bool get _hasRelations => _children.isNotEmpty || _orphanIds.isNotEmpty;

  static bool _hasParent(Session session) =>
      session.metadata?.parentSessionId != null;

  static String? _nearestVisibleAncestor(
    Session session,
    Set<String> visibleIds,
    Map<String, Session>? catalog,
  ) {
    final seen = <String>{session.id};
    var parentId = session.metadata?.parentSessionId;
    for (var i = 0; parentId != null && i < _maxAncestryDepth; i++) {
      if (!seen.add(parentId)) return null; // cycle
      if (visibleIds.contains(parentId)) return parentId;
      parentId = catalog?[parentId]?.metadata?.parentSessionId;
    }
    return null;
  }
}

/// Descendant counts for a parent's sub-session disclosure.
@immutable
class SubSessionSummary {
  const SubSessionSummary({
    required this.total,
    required this.working,
    required this.needsAttention,
  });

  final int total;
  final int working;
  final int needsAttention;

  @override
  bool operator ==(Object other) =>
      other is SubSessionSummary &&
      other.total == total &&
      other.working == working &&
      other.needsAttention == needsAttention;

  @override
  int get hashCode => Object.hash(total, working, needsAttention);
}

/// Every loaded session spawned by [parentId], most recently active first.
List<Session> subSessionsOf(Map<String, Session> catalog, String parentId) {
  return [
    for (final s in catalog.values)
      if (s.metadata?.parentSessionId == parentId) s,
  ]..sort((a, b) {
    final c = b.activeAt.compareTo(a.activeAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
}
