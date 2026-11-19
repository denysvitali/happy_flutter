/// Reader-side resolution of a [FolderDoc] against the known sessions.
///
/// Readers never fail on a bad document; they degrade (spec "Rules for
/// readers"):
/// - a folder whose parent is missing, has a different anchor or forms a
///   cycle shows at its anchor's top level;
/// - a folder anchored at a session that is not listed is hidden, and its
///   sessions show as unfiled;
/// - a session whose folder is missing/hidden, or whose folder's anchor is
///   not its parent session, shows as unfiled.
library;

import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../models/session.dart';
import 'session_folders_doc.dart';

/// A folder a session may move into, with its full path.
@immutable
class FolderTarget {
  const FolderTarget({required this.id, required this.path});

  final String id;
  final String path;
}

@immutable
class FolderTree {
  const FolderTree._({
    required this.doc,
    required Map<String, String?> parentOf,
    required Map<(String?, String?), List<String>> children,
    required Map<String, String> sessionFolder,
    List<Object?> inputs = const [],
  }) : _parentOf = parentOf,
       _children = children,
       _sessionFolder = sessionFolder,
       _inputs = inputs;

  /// Resolves [doc] against [catalog] (every listed session).
  factory FolderTree.build(FolderDoc doc, Map<String, Session> catalog) {
    if (doc.isEmpty) return empty;
    final visible = <String>{
      for (final e in doc.folders.entries)
        if (e.value.anchor == null || catalog.containsKey(e.value.anchor))
          e.key,
    };
    final tentative = <String, String?>{};
    for (final id in visible) {
      final folder = doc.folders[id]!;
      final parent = folder.parent;
      final parentFolder = parent == null ? null : doc.folders[parent];
      final ok =
          parentFolder != null &&
          parentFolder.anchor == folder.anchor &&
          visible.contains(parent);
      tentative[id] = ok ? parent : null;
    }
    // Every member of a cycle moves to its anchor's top level; folders
    // that merely hang below a cycle keep their parent.
    final parentOf = <String, String?>{};
    for (final id in visible) {
      final seen = <String>{};
      var inCycle = false;
      for (
        var cursor = tentative[id];
        cursor != null;
        cursor = tentative[cursor]
      ) {
        if (cursor == id) {
          inCycle = true;
          break;
        }
        if (!seen.add(cursor)) break;
      }
      parentOf[id] = inCycle ? null : tentative[id];
    }
    final children = <(String?, String?), List<String>>{};
    for (final id in visible) {
      final key = (doc.folders[id]!.anchor, parentOf[id]);
      (children[key] ??= <String>[]).add(id);
    }
    int byName(String a, String b) {
      final c = compareFolderNames(doc.folders[a]!.name, doc.folders[b]!.name);
      return c != 0 ? c : a.compareTo(b);
    }

    for (final list in children.values) {
      list.sort(byName);
    }
    final sessionFolder = <String, String>{};
    for (final MapEntry(key: sessionId, value: folderId)
        in doc.sessions.entries) {
      final session = catalog[sessionId];
      final folder = doc.folders[folderId];
      if (session == null || folder == null || !visible.contains(folderId)) {
        continue;
      }
      if (folder.anchor != session.metadata?.parentSessionId) continue;
      sessionFolder[sessionId] = folderId;
    }
    return FolderTree._(
      doc: doc,
      inputs: _catalogInputs(doc, catalog),
      parentOf: parentOf,
      children: {
        for (final e in children.entries) e.key: List.unmodifiable(e.value),
      },
      sessionFolder: sessionFolder,
    );
  }

  static const FolderTree empty = FolderTree._(
    doc: FolderDoc.empty,
    parentOf: {},
    children: {},
    sessionFolder: {},
  );

  final FolderDoc doc;

  /// The catalog facts the resolution read; equal trees skip rebuilds.
  final List<Object?> _inputs;
  final Map<String, String?> _parentOf;
  final Map<(String?, String?), List<String>> _children;
  final Map<String, String> _sessionFolder;

  bool get isEmpty => _parentOf.isEmpty;

  bool isVisible(String folderId) => _parentOf.containsKey(folderId);

  SessionFolder? folder(String folderId) =>
      isVisible(folderId) ? doc.folders[folderId] : null;

  /// Displayed parent folder (null: the anchor's top level).
  String? parentOf(String folderId) => _parentOf[folderId];

  /// Visible folders directly under [parent] within [anchor], sorted.
  List<String> childrenOf({String? anchor, String? parent}) =>
      _children[(anchor, parent)] ?? const <String>[];

  /// The folder [sessionId] displays in; null when unfiled.
  String? folderOfSession(String sessionId) => _sessionFolder[sessionId];

  /// Displayed path, top-level ancestor first.
  String path(String folderId) {
    final names = <String>[];
    final seen = <String>{};
    String? cursor = folderId;
    while (cursor != null && seen.add(cursor)) {
      final f = doc.folders[cursor];
      if (f == null) break;
      names.add(f.name);
      cursor = _parentOf[cursor];
    }
    return names.reversed.join(' / ');
  }

  /// [folderId] and every visible folder below it.
  Set<String> subtree(String folderId) {
    final out = <String>{};
    final anchor = doc.folders[folderId]?.anchor;
    void walk(String id) {
      if (!out.add(id)) return;
      for (final child in childrenOf(anchor: anchor, parent: id)) {
        walk(child);
      }
    }

    walk(folderId);
    return out;
  }

  /// Folders a session whose parent session is [parentSessionId] may join,
  /// sorted by path.
  List<FolderTarget> targetsFor(String? parentSessionId) {
    final out = <FolderTarget>[];
    void walk(String? parent) {
      for (final id in childrenOf(anchor: parentSessionId, parent: parent)) {
        out.add(FolderTarget(id: id, path: path(id)));
        walk(id);
      }
    }

    walk(null);
    return out;
  }

  /// Folders [folderId] may move under (excluding itself and its
  /// subtree), sorted by path.
  List<FolderTarget> moveTargetsFor(String folderId) {
    final excluded = subtree(folderId);
    final anchor = doc.folders[folderId]?.anchor;
    return [
      for (final t in targetsFor(anchor))
        if (!excluded.contains(t.id)) t,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is FolderTree &&
      other.doc == doc &&
      listEquals(other._inputs, _inputs);

  @override
  int get hashCode => Object.hash(doc, Object.hashAll(_inputs));
}

/// Which listed sessions the resolution depends on: anchors and the
/// parent of every assigned session.
List<Object?> _catalogInputs(FolderDoc doc, Map<String, Session> catalog) {
  final anchors = <String>{
    for (final f in doc.folders.values) ?f.anchor,
  }.toList()..sort();
  final assigned = doc.sessions.keys.toList()..sort();
  return [
    for (final id in anchors) catalog.containsKey(id),
    for (final id in assigned)
      catalog.containsKey(id) ? catalog[id]!.metadata?.parentSessionId : false,
  ];
}
