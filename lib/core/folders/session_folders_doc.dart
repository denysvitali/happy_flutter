/// The decrypted session-folders document and the writer rules.
///
/// Wire format and rules: happy-cli-go
/// `docs/operations/session-folders.md` (reference implementation in
/// `internal/sessionfolders/doc.go`). Every edit is a pure [FolderEdit] so
/// a CAS retry can re-apply it to a newer document.
library;

import 'dart:math';

import 'package:flutter/foundation.dart' show immutable, mapEquals;

/// Envelope version this app reads and writes.
const int sessionFoldersVersion = 1;
const int maxSessionFolders = 500;
const int maxSessionFolderDepth = 8;
const int maxSessionFolderNameLength = 64;

/// Why an edit was refused.
enum FolderRule {
  emptyName,
  nameTooLong,
  controlCharacters,
  duplicateName,
  tooManyFolders,
  tooDeep,
  cycle,
  missingFolder,
  wrongAnchor,
  readOnly,
}

class FolderRuleException implements Exception {
  const FolderRuleException(this.rule);
  final FolderRule rule;

  @override
  String toString() => 'FolderRuleException(${rule.name})';
}

/// One folder. A null [parent] is its anchor's top level; a null [anchor]
/// is account level.
@immutable
class SessionFolder {
  const SessionFolder({required this.name, this.parent, this.anchor});

  final String name;
  final String? parent;
  final String? anchor;

  SessionFolder copyWith({String? name, String? Function()? parent}) =>
      SessionFolder(
        name: name ?? this.name,
        parent: parent == null ? this.parent : parent(),
        anchor: anchor,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'parent': parent,
    'anchor': anchor,
  };

  @override
  bool operator ==(Object other) =>
      other is SessionFolder &&
      other.name == name &&
      other.parent == parent &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(name, parent, anchor);
}

@immutable
class FolderDoc {
  const FolderDoc({
    this.folders = const <String, SessionFolder>{},
    this.sessions = const <String, String>{},
  });

  /// Lenient decode: malformed entries are skipped, never fatal.
  factory FolderDoc.fromJson(Object? json) {
    if (json is! Map) return empty;
    final folders = <String, SessionFolder>{};
    final rawFolders = json['folders'];
    if (rawFolders is Map) {
      for (final MapEntry(:key, :value) in rawFolders.entries) {
        if (key is! String || key.isEmpty || value is! Map) continue;
        final name = value['name'];
        if (name is! String) continue;
        folders[key] = SessionFolder(
          name: name,
          parent: _nonEmpty(value['parent']),
          anchor: _nonEmpty(value['anchor']),
        );
      }
    }
    final sessions = <String, String>{};
    final rawSessions = json['sessions'];
    if (rawSessions is Map) {
      for (final MapEntry(:key, :value) in rawSessions.entries) {
        if (key is String && key.isNotEmpty && value is String) {
          if (value.isNotEmpty) sessions[key] = value;
        }
      }
    }
    return FolderDoc(folders: folders, sessions: sessions);
  }

  static const FolderDoc empty = FolderDoc();

  final Map<String, SessionFolder> folders;

  /// Session id -> folder id.
  final Map<String, String> sessions;

  bool get isEmpty => folders.isEmpty && sessions.isEmpty;

  Map<String, Object?> toJson() => {
    'folders': {for (final e in folders.entries) e.key: e.value.toJson()},
    'sessions': sessions,
  };

  /// Folders from [id] up to its anchor's top level, counting [id]; -1
  /// when the chain is broken or cyclic.
  int depth(String id) {
    final seen = <String>{};
    var n = 0;
    String? cursor = id;
    while (cursor != null) {
      final folder = folders[cursor];
      if (folder == null || !seen.add(cursor)) return -1;
      n++;
      cursor = folder.parent;
    }
    return n;
  }

  /// Depth of the deepest folder below [id], counting [id].
  int height(String id, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!visited.add(id)) return 1;
    var h = 1;
    for (final e in folders.entries) {
      if (e.value.parent == id && e.key != id) {
        h = max(h, 1 + height(e.key, visited));
      }
    }
    return h;
  }

  /// Whether [id] is [ancestor] or lies below it.
  bool isDescendant(String id, String ancestor) {
    final seen = <String>{};
    String? cursor = id;
    while (cursor != null && seen.add(cursor)) {
      if (cursor == ancestor) return true;
      cursor = folders[cursor]?.parent;
    }
    return false;
  }

  /// Names from the top-level ancestor down, joined by " / ".
  String path(String id) {
    final names = <String>[];
    final seen = <String>{};
    String? cursor = id;
    while (cursor != null && seen.add(cursor)) {
      final folder = folders[cursor];
      if (folder == null) break;
      names.add(folder.name);
      cursor = folder.parent;
    }
    return names.reversed.join(' / ');
  }

  @override
  bool operator ==(Object other) =>
      other is FolderDoc &&
      mapEquals(other.folders, folders) &&
      mapEquals(other.sessions, sessions);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(folders.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(sessions.entries.map((e) => (e.key, e.value))),
  );
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

final Random _random = Random.secure();

/// `f` followed by 16 random lowercase hex digits.
String newFolderId() {
  final buffer = StringBuffer('f');
  for (var i = 0; i < 8; i++) {
    buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Trims [name] and checks it; throws [FolderRuleException].
String normalizeFolderName(String name) {
  final trimmed = name.trim();
  final length = trimmed.runes.length;
  if (length == 0) throw const FolderRuleException(FolderRule.emptyName);
  if (length > maxSessionFolderNameLength) {
    throw const FolderRuleException(FolderRule.nameTooLong);
  }
  for (final rune in trimmed.runes) {
    if (rune < 0x20 || (rune >= 0x7f && rune < 0xa0)) {
      throw const FolderRuleException(FolderRule.controlCharacters);
    }
  }
  return trimmed;
}

/// The rule [name] breaks, or null when it is valid.
FolderRule? folderNameProblem(String name) {
  try {
    normalizeFolderName(name);
    return null;
  } on FolderRuleException catch (e) {
    return e.rule;
  }
}

void _checkSiblingName(
  FolderDoc doc,
  String name, {
  required String? parent,
  required String? anchor,
  String? except,
}) {
  final lower = name.toLowerCase();
  for (final e in doc.folders.entries) {
    final f = e.value;
    if (e.key != except &&
        f.parent == parent &&
        f.anchor == anchor &&
        f.name.toLowerCase() == lower) {
      throw const FolderRuleException(FolderRule.duplicateName);
    }
  }
}

/// Folder sort order: case-insensitive and numeric-aware ("2" < "10").
int compareFolderNames(String a, String b) {
  final x = a.toLowerCase();
  final y = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < x.length && j < y.length) {
    final cx = x.codeUnitAt(i);
    final cy = y.codeUnitAt(j);
    if (_isDigit(cx) && _isDigit(cy)) {
      var ei = i;
      while (ei < x.length && _isDigit(x.codeUnitAt(ei))) {
        ei++;
      }
      var ej = j;
      while (ej < y.length && _isDigit(y.codeUnitAt(ej))) {
        ej++;
      }
      final nx = x.substring(i, ei).replaceFirst(RegExp('^0+(?=.)'), '');
      final ny = y.substring(j, ej).replaceFirst(RegExp('^0+(?=.)'), '');
      if (nx.length != ny.length) return nx.length - ny.length;
      final c = nx.compareTo(ny);
      if (c != 0) return c;
      i = ei;
      j = ej;
      continue;
    }
    if (cx != cy) return cx - cy;
    i++;
    j++;
  }
  return (x.length - i) - (y.length - j);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// One user edit. [apply] is pure and deterministic, so a lost CAS race
/// re-applies it to the newer document.
sealed class FolderEdit {
  const FolderEdit();

  FolderDoc apply(FolderDoc doc);
}

class CreateFolder extends FolderEdit {
  const CreateFolder({
    required this.id,
    required this.name,
    this.parent,
    this.anchor,
  });

  final String id;
  final String name;
  final String? parent;

  /// Only used for a top-level folder; a subfolder takes its parent's.
  final String? anchor;

  @override
  FolderDoc apply(FolderDoc doc) {
    final normalized = normalizeFolderName(name);
    var effectiveAnchor = anchor;
    final parentId = parent;
    if (parentId != null) {
      final p = doc.folders[parentId];
      if (p == null) throw const FolderRuleException(FolderRule.missingFolder);
      if (anchor != null && anchor != p.anchor) {
        throw const FolderRuleException(FolderRule.wrongAnchor);
      }
      effectiveAnchor = p.anchor;
    }
    final folder = SessionFolder(
      name: normalized,
      parent: parentId,
      anchor: effectiveAnchor,
    );
    // A retry of a create that already landed is a no-op.
    if (doc.folders[id] == folder) return doc;
    if (doc.folders.containsKey(id)) {
      throw const FolderRuleException(FolderRule.duplicateName);
    }
    if (doc.folders.length >= maxSessionFolders) {
      throw const FolderRuleException(FolderRule.tooManyFolders);
    }
    if (parentId != null) {
      final d = doc.depth(parentId);
      if (d < 0 || d + 1 > maxSessionFolderDepth) {
        throw const FolderRuleException(FolderRule.tooDeep);
      }
    }
    _checkSiblingName(
      doc,
      normalized,
      parent: parentId,
      anchor: effectiveAnchor,
    );
    return FolderDoc(
      folders: {...doc.folders, id: folder},
      sessions: doc.sessions,
    );
  }
}

class RenameFolder extends FolderEdit {
  const RenameFolder({required this.id, required this.name});

  final String id;
  final String name;

  @override
  FolderDoc apply(FolderDoc doc) {
    final f = doc.folders[id];
    if (f == null) throw const FolderRuleException(FolderRule.missingFolder);
    final normalized = normalizeFolderName(name);
    if (normalized == f.name) return doc;
    _checkSiblingName(
      doc,
      normalized,
      parent: f.parent,
      anchor: f.anchor,
      except: id,
    );
    return FolderDoc(
      folders: {
        ...doc.folders,
        id: f.copyWith(name: normalized),
      },
      sessions: doc.sessions,
    );
  }
}

class MoveFolder extends FolderEdit {
  const MoveFolder({required this.id, this.parent});

  final String id;

  /// Null moves the folder to its anchor's top level.
  final String? parent;

  @override
  FolderDoc apply(FolderDoc doc) {
    final f = doc.folders[id];
    if (f == null) throw const FolderRuleException(FolderRule.missingFolder);
    final target = parent;
    if (target != null) {
      final p = doc.folders[target];
      if (p == null) throw const FolderRuleException(FolderRule.missingFolder);
      if (p.anchor != f.anchor) {
        throw const FolderRuleException(FolderRule.wrongAnchor);
      }
      if (doc.isDescendant(target, id)) {
        throw const FolderRuleException(FolderRule.cycle);
      }
      final d = doc.depth(target);
      if (d < 0 || d + doc.height(id) > maxSessionFolderDepth) {
        throw const FolderRuleException(FolderRule.tooDeep);
      }
    } else if (doc.height(id) > maxSessionFolderDepth) {
      throw const FolderRuleException(FolderRule.tooDeep);
    }
    _checkSiblingName(
      doc,
      f.name,
      parent: target,
      anchor: f.anchor,
      except: id,
    );
    return FolderDoc(
      folders: {
        ...doc.folders,
        id: f.copyWith(parent: () => target),
      },
      sessions: doc.sessions,
    );
  }
}

/// Removes a folder; its subfolders and sessions move to its parent
/// without renaming (siblings may then share a name, which readers accept).
class DeleteFolder extends FolderEdit {
  const DeleteFolder(this.id);

  final String id;

  @override
  FolderDoc apply(FolderDoc doc) {
    final f = doc.folders[id];
    // Deleting a folder someone else already removed is not a failure.
    if (f == null) return doc;
    final folders = <String, SessionFolder>{
      for (final e in doc.folders.entries)
        if (e.key != id)
          e.key: e.value.parent == id
              ? e.value.copyWith(parent: () => f.parent)
              : e.value,
    };
    final sessions = <String, String>{};
    for (final e in doc.sessions.entries) {
      if (e.value != id) {
        sessions[e.key] = e.value;
      } else if (f.parent != null) {
        sessions[e.key] = f.parent!;
      }
    }
    return FolderDoc(folders: folders, sessions: sessions);
  }
}

/// Puts sessions into [folderId] (null = no folder). Each session maps to
/// its parent session id (null for top-level): a session may only join a
/// folder anchored at its parent.
class AssignSessions extends FolderEdit {
  const AssignSessions({required this.parents, this.folderId});

  final Map<String, String?> parents;
  final String? folderId;

  @override
  FolderDoc apply(FolderDoc doc) {
    final sessions = Map<String, String>.of(doc.sessions);
    final target = folderId;
    if (target == null) {
      parents.keys.forEach(sessions.remove);
    } else {
      final f = doc.folders[target];
      if (f == null) throw const FolderRuleException(FolderRule.missingFolder);
      for (final MapEntry(key: sessionId, value: parentId) in parents.entries) {
        if (f.anchor != parentId) {
          throw const FolderRuleException(FolderRule.wrongAnchor);
        }
        sessions[sessionId] = target;
      }
    }
    if (mapEquals(sessions, doc.sessions)) return doc;
    return FolderDoc(folders: doc.folders, sessions: sessions);
  }
}

/// A deleted session: drops its assignment and every folder anchored at
/// it, with those folders' assignments.
class ForgetSession extends FolderEdit {
  const ForgetSession(this.sessionId);

  final String sessionId;

  @override
  FolderDoc apply(FolderDoc doc) {
    final folders = <String, SessionFolder>{
      for (final e in doc.folders.entries)
        if (e.value.anchor != sessionId) e.key: e.value,
    };
    final sessions = <String, String>{
      for (final e in doc.sessions.entries)
        if (e.key != sessionId && folders.containsKey(e.value)) e.key: e.value,
    };
    final next = FolderDoc(folders: folders, sessions: sessions);
    return next == doc ? doc : next;
  }
}

/// Whether [edit] cannot change anything on [doc] (skips a write).
bool folderEditIsNoop(FolderEdit edit, FolderDoc doc) {
  try {
    return identical(edit.apply(doc), doc);
  } on FolderRuleException {
    return false;
  }
}
