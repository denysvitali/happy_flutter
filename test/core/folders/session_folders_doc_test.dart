import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/folders/session_folders_doc.dart';

FolderDoc _doc(
  Map<String, SessionFolder> folders, [
  Map<String, String> sessions = const {},
]) => FolderDoc(folders: folders, sessions: sessions);

const _work = SessionFolder(name: 'Work');

Matcher _refused(FolderRule rule) =>
    throwsA(isA<FolderRuleException>().having((e) => e.rule, 'rule', rule));

/// A chain f1 > f2 > … > f[n] under account level.
FolderDoc _chain(int n, {String? anchor}) => _doc({
  for (var i = 1; i <= n; i++)
    'f$i': SessionFolder(
      name: 'L$i',
      parent: i == 1 ? null : 'f${i - 1}',
      anchor: anchor,
    ),
});

void main() {
  group('names', () {
    test('are trimmed and must be 1-64 characters', () {
      expect(normalizeFolderName('  Work  '), 'Work');
      expect(() => normalizeFolderName('   '), _refused(FolderRule.emptyName));
      expect(normalizeFolderName('a' * 64), hasLength(64));
      expect(
        () => normalizeFolderName('a' * 65),
        _refused(FolderRule.nameTooLong),
      );
      // Counted in characters, not UTF-16 units.
      expect(normalizeFolderName('😀' * 64).runes.length, 64);
    });

    test('reject control characters', () {
      expect(
        () => normalizeFolderName('a\nb'),
        _refused(FolderRule.controlCharacters),
      );
      expect(
        () => normalizeFolderName('a\u0085b'),
        _refused(FolderRule.controlCharacters),
      );
    });

    test('sort case-insensitively and numeric-aware', () {
      final names = ['b', 'Item 10', 'item 2', 'A', 'Item 02x'];
      names.sort(compareFolderNames);
      expect(names, ['A', 'b', 'item 2', 'Item 02x', 'Item 10']);
    });

    test('folder ids are f + 16 lowercase hex digits', () {
      for (var i = 0; i < 20; i++) {
        expect(newFolderId(), matches(RegExp(r'^f[0-9a-f]{16}$')));
      }
    });
  });

  group('create', () {
    test('adds an account-level folder and a subfolder', () {
      var doc = const CreateFolder(
        id: 'f1',
        name: ' Work ',
      ).apply(FolderDoc.empty);
      doc = const CreateFolder(
        id: 'f2',
        name: 'Client',
        parent: 'f1',
      ).apply(doc);
      expect(doc.folders['f1'], const SessionFolder(name: 'Work'));
      expect(
        doc.folders['f2'],
        const SessionFolder(name: 'Client', parent: 'f1'),
      );
      expect(doc.path('f2'), 'Work / Client');
    });

    test('a subfolder takes its parent anchor', () {
      final doc = _doc({'f1': const SessionFolder(name: 'A', anchor: 's1')});
      final next = const CreateFolder(
        id: 'f2',
        name: 'B',
        parent: 'f1',
      ).apply(doc);
      expect(next.folders['f2']!.anchor, 's1');
      expect(
        () => const CreateFolder(
          id: 'f3',
          name: 'C',
          parent: 'f1',
          anchor: 's2',
        ).apply(doc),
        _refused(FolderRule.wrongAnchor),
      );
    });

    test('sibling names are unique case-insensitively per parent/anchor', () {
      final doc = _doc({'f1': _work});
      expect(
        () => const CreateFolder(id: 'f2', name: 'WORK').apply(doc),
        _refused(FolderRule.duplicateName),
      );
      // Same name under another anchor or parent is fine.
      const CreateFolder(id: 'f2', name: 'work', anchor: 's1').apply(doc);
      const CreateFolder(id: 'f3', name: 'Work', parent: 'f1').apply(doc);
    });

    test('limits folders to 500 and depth to 8', () {
      final full = _doc({
        for (var i = 0; i < maxSessionFolders; i++)
          'f$i': SessionFolder(name: 'n$i'),
      });
      expect(
        () => const CreateFolder(id: 'x', name: 'x').apply(full),
        _refused(FolderRule.tooManyFolders),
      );
      final deep = _chain(8);
      expect(
        () => const CreateFolder(id: 'x', name: 'x', parent: 'f8').apply(deep),
        _refused(FolderRule.tooDeep),
      );
      const CreateFolder(id: 'x', name: 'x', parent: 'f7').apply(deep);
    });

    test('re-applying a create that already landed is a no-op', () {
      final doc = const CreateFolder(
        id: 'f1',
        name: 'Work',
      ).apply(FolderDoc.empty);
      final again = const CreateFolder(id: 'f1', name: 'Work').apply(doc);
      expect(identical(again, doc), isTrue);
    });

    test('a missing parent is refused', () {
      expect(
        () => const CreateFolder(
          id: 'f1',
          name: 'A',
          parent: 'nope',
        ).apply(FolderDoc.empty),
        _refused(FolderRule.missingFolder),
      );
    });
  });

  group('rename and move', () {
    test('rename checks sibling names but allows a case change', () {
      final doc = _doc({'f1': _work, 'f2': const SessionFolder(name: 'Home')});
      expect(
        () => const RenameFolder(id: 'f2', name: 'work').apply(doc),
        _refused(FolderRule.duplicateName),
      );
      final next = const RenameFolder(id: 'f1', name: 'WORK').apply(doc);
      expect(next.folders['f1']!.name, 'WORK');
    });

    test('move refuses cycles', () {
      final doc = _chain(3);
      expect(
        () => const MoveFolder(id: 'f1', parent: 'f3').apply(doc),
        _refused(FolderRule.cycle),
      );
      expect(
        () => const MoveFolder(id: 'f1', parent: 'f1').apply(doc),
        _refused(FolderRule.cycle),
      );
    });

    test('move keeps the anchor and the depth limit', () {
      final doc = _doc({
        ..._chain(6).folders,
        'g1': const SessionFolder(name: 'G1'),
        'g2': const SessionFolder(name: 'G2', parent: 'g1'),
        'g3': const SessionFolder(name: 'G3', parent: 'g2'),
        'a1': const SessionFolder(name: 'A1', anchor: 's1'),
      });
      // 6 + a subtree of height 3 = 9 levels.
      expect(
        () => const MoveFolder(id: 'g1', parent: 'f6').apply(doc),
        _refused(FolderRule.tooDeep),
      );
      final moved = const MoveFolder(id: 'g1', parent: 'f5').apply(doc);
      expect(moved.depth('g3'), 8);
      expect(
        () => const MoveFolder(id: 'a1', parent: 'f1').apply(doc),
        _refused(FolderRule.wrongAnchor),
      );
      final top = const MoveFolder(id: 'f3').apply(doc);
      expect(top.folders['f3']!.parent, isNull);
    });

    test('move checks the name among the new siblings', () {
      final doc = _doc({
        'f1': _work,
        'f2': const SessionFolder(name: 'Home'),
        'f3': const SessionFolder(name: 'work', parent: 'f2'),
      });
      expect(
        () => const MoveFolder(id: 'f3').apply(doc),
        _refused(FolderRule.duplicateName),
      );
    });
  });

  group('delete', () {
    test('moves subfolders and sessions up without renaming', () {
      final doc = _doc(
        {
          'f1': _work,
          'f2': const SessionFolder(name: 'Mid', parent: 'f1'),
          'f3': const SessionFolder(name: 'Work', parent: 'f2'),
          'f4': const SessionFolder(name: 'Leaf', parent: 'f2'),
        },
        {'s1': 'f2', 's2': 'f1'},
      );
      final next = const DeleteFolder('f2').apply(doc);
      expect(next.folders.keys, unorderedEquals(['f1', 'f3', 'f4']));
      expect(next.folders['f3']!.parent, 'f1');
      expect(next.folders['f3']!.name, 'Work');
      expect(next.sessions, {'s1': 'f1', 's2': 'f1'});
    });

    test('a top-level folder leaves its sessions unfiled', () {
      final doc = _doc(
        {'f1': _work, 'f2': const SessionFolder(name: 'Sub', parent: 'f1')},
        {'s1': 'f1'},
      );
      final next = const DeleteFolder('f1').apply(doc);
      expect(next.sessions, isEmpty);
      expect(next.folders['f2']!.parent, isNull);
    });

    test('top-level siblings may share a name afterwards', () {
      final doc = _doc({
        'f1': _work,
        'f2': const SessionFolder(name: 'Outer'),
        'f3': const SessionFolder(name: 'work', parent: 'f2'),
      });
      final next = const DeleteFolder('f2').apply(doc);
      expect(next.folders['f1']!.name, 'Work');
      expect(next.folders['f3']!.name, 'work');
      expect(next.folders['f3']!.parent, isNull);
    });

    test('deleting a folder that is already gone is a no-op', () {
      final doc = _doc({'f1': _work});
      expect(identical(const DeleteFolder('x').apply(doc), doc), isTrue);
    });
  });

  group('assign', () {
    final doc = _doc({
      'f1': _work,
      'c1': const SessionFolder(name: 'Children', anchor: 'p1'),
    });

    test('top-level sessions join account-level folders only', () {
      final next = const AssignSessions(
        parents: {'s1': null, 's2': null},
        folderId: 'f1',
      ).apply(doc);
      expect(next.sessions, {'s1': 'f1', 's2': 'f1'});
      expect(
        () => const AssignSessions(
          parents: {'s1': null},
          folderId: 'c1',
        ).apply(doc),
        _refused(FolderRule.wrongAnchor),
      );
    });

    test('a child only joins folders anchored at its parent', () {
      final next = const AssignSessions(
        parents: {'k1': 'p1'},
        folderId: 'c1',
      ).apply(doc);
      expect(next.sessions, {'k1': 'c1'});
      expect(
        () => const AssignSessions(
          parents: {'k1': 'p1'},
          folderId: 'f1',
        ).apply(doc),
        _refused(FolderRule.wrongAnchor),
      );
      expect(
        () => const AssignSessions(
          parents: {'k2': 'p2'},
          folderId: 'c1',
        ).apply(doc),
        _refused(FolderRule.wrongAnchor),
      );
    });

    test('no folder removes assignments; a missing folder is refused', () {
      final filed = _doc(doc.folders, {'s1': 'f1', 's2': 'f1'});
      final next = const AssignSessions(parents: {'s1': null}).apply(filed);
      expect(next.sessions, {'s2': 'f1'});
      expect(
        () => const AssignSessions(
          parents: {'s1': null},
          folderId: 'gone',
        ).apply(filed),
        _refused(FolderRule.missingFolder),
      );
      expect(
        identical(
          const AssignSessions(parents: {'s9': null}).apply(filed),
          filed,
        ),
        isTrue,
      );
    });
  });

  test('forgetting a deleted session drops it and its anchored folders', () {
    final doc = _doc(
      {
        'f1': _work,
        'c1': const SessionFolder(name: 'C', anchor: 'p1'),
        'c2': const SessionFolder(name: 'D', parent: 'c1', anchor: 'p1'),
      },
      {'p1': 'f1', 'k1': 'c2', 'k2': 'c1', 's1': 'f1'},
    );
    final next = const ForgetSession('p1').apply(doc);
    expect(next.folders.keys, ['f1']);
    expect(next.sessions, {'s1': 'f1'});
    expect(identical(const ForgetSession('nobody').apply(next), next), isTrue);
  });

  group('wire JSON', () {
    test('round-trips with null parent/anchor', () {
      final doc = _doc(
        {
          'f0123456789abcdef': _work,
          'f1': const SessionFolder(name: 'Sub', parent: 'f0123456789abcdef'),
        },
        {'s1': 'f1'},
      );
      final json = doc.toJson();
      expect(json['folders'], {
        'f0123456789abcdef': {'name': 'Work', 'parent': null, 'anchor': null},
        'f1': {'name': 'Sub', 'parent': 'f0123456789abcdef', 'anchor': null},
      });
      expect(FolderDoc.fromJson(json), doc);
    });

    test('decoding skips malformed entries instead of failing', () {
      final doc = FolderDoc.fromJson({
        'folders': {
          'ok': {'name': 'Ok', 'parent': '', 'anchor': null},
          'bad': {'parent': null},
          'worse': 'x',
        },
        'sessions': {'s1': 'ok', 's2': 7, 's3': ''},
        'extra': true,
      });
      expect(doc.folders, {'ok': const SessionFolder(name: 'Ok')});
      expect(doc.sessions, {'s1': 'ok'});
      expect(FolderDoc.fromJson('garbage'), FolderDoc.empty);
    });
  });
}
