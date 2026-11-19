import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/folders/session_folders_doc.dart';
import 'package:happy_flutter/core/folders/session_folders_tree.dart';
import 'package:happy_flutter/core/models/session.dart';

Session _s(String id, {String? parent}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'online',
  metadata: Metadata(path: '/w/$id', parentSessionId: parent),
);

Map<String, Session> _catalog(List<Session> sessions) => {
  for (final s in sessions) s.id: s,
};

void main() {
  test('sorts children by name and resolves paths', () {
    final tree = FolderTree.build(
      const FolderDoc(
        folders: {
          'a': SessionFolder(name: 'item 10'),
          'b': SessionFolder(name: 'Item 2'),
          'c': SessionFolder(name: 'Sub', parent: 'a'),
        },
      ),
      const {},
    );
    expect(tree.childrenOf(), ['b', 'a']);
    expect(tree.childrenOf(parent: 'a'), ['c']);
    expect(tree.path('c'), 'item 10 / Sub');
    expect(tree.targetsFor(null).map((t) => t.path), [
      'Item 2',
      'item 10',
      'item 10 / Sub',
    ]);
    expect(tree.moveTargetsFor('a').map((t) => t.id), ['b']);
  });

  test('a folder with a missing or foreign-anchor parent shows at the top', () {
    final tree = FolderTree.build(
      const FolderDoc(
        folders: {
          'orphan': SessionFolder(name: 'Orphan', parent: 'gone'),
          'p': SessionFolder(name: 'P', anchor: 's1'),
          'mixed': SessionFolder(name: 'Mixed', parent: 'p'),
        },
      ),
      _catalog([_s('s1')]),
    );
    expect(tree.childrenOf(), ['mixed', 'orphan']);
    expect(tree.parentOf('mixed'), isNull);
    expect(tree.childrenOf(anchor: 's1'), ['p']);
  });

  test('cycle members show at the top; folders below a cycle keep it', () {
    final tree = FolderTree.build(
      const FolderDoc(
        folders: {
          'x': SessionFolder(name: 'X', parent: 'y'),
          'y': SessionFolder(name: 'Y', parent: 'x'),
          'z': SessionFolder(name: 'Z', parent: 'x'),
        },
      ),
      const {},
    );
    expect(tree.childrenOf(), ['x', 'y']);
    expect(tree.childrenOf(parent: 'x'), ['z']);
    expect(tree.path('z'), 'X / Z');
  });

  test('folders anchored at an unlisted session are hidden', () {
    final tree = FolderTree.build(
      const FolderDoc(
        folders: {'c': SessionFolder(name: 'C', anchor: 'gone')},
        sessions: {'k': 'c'},
      ),
      _catalog([_s('k', parent: 'gone')]),
    );
    expect(tree.isVisible('c'), isFalse);
    expect(tree.childrenOf(anchor: 'gone'), isEmpty);
    expect(tree.folderOfSession('k'), isNull);
  });

  test('sessions in a missing or wrongly anchored folder show unfiled', () {
    final tree = FolderTree.build(
      const FolderDoc(
        folders: {
          'top': SessionFolder(name: 'Top'),
          'kids': SessionFolder(name: 'Kids', anchor: 'p'),
        },
        sessions: {
          'p': 'top',
          'k1': 'kids',
          'k2': 'top',
          'lone': 'kids',
          'nobody': 'gone',
        },
      ),
      _catalog([
        _s('p'),
        _s('k1', parent: 'p'),
        _s('k2', parent: 'p'),
        _s('lone'),
        _s('nobody'),
      ]),
    );
    expect(tree.folderOfSession('p'), 'top');
    expect(tree.folderOfSession('k1'), 'kids');
    // A child never leaves its parent; a top-level session never joins a
    // session's folder.
    expect(tree.folderOfSession('k2'), isNull);
    expect(tree.folderOfSession('lone'), isNull);
    expect(tree.folderOfSession('nobody'), isNull);
    expect(tree.targetsFor('p').map((t) => t.id), ['kids']);
    expect(tree.targetsFor(null).map((t) => t.id), ['top']);
  });

  test(
    'equal inputs build equal trees; catalog changes that matter differ',
    () {
      const doc = FolderDoc(
        folders: {'c': SessionFolder(name: 'C', anchor: 'p')},
        sessions: {'k': 'c'},
      );
      final base = [_s('p'), _s('k', parent: 'p'), _s('other')];
      final a = FolderTree.build(doc, _catalog(base));
      final b = FolderTree.build(doc, _catalog([...base, _s('new')]));
      expect(a, b);
      final c = FolderTree.build(doc, _catalog([_s('k', parent: 'p')]));
      expect(a == c, isFalse);
    },
  );
}
