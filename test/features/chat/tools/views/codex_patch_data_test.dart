import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_patch_data.dart';

void main() {
  group('CodexPatchData', () {
    test('structured changes take precedence over a separate patch body', () {
      final patch = CodexPatchData.fromTool({
        'input': {'auto_approved': true},
        'content': {
          'arguments': {
            'changes': {
              'lib/chosen.dart': {
                'updated': {'oldText': 'before', 'newText': 'after'},
              },
            },
          },
        },
        'result': '''
*** Begin Patch
*** Add File: ignored.dart
+ignored
*** End Patch
''',
      });

      expect(patch.autoApproved, isTrue);
      final change = patch.fileChanges.single;
      expect(change.path, 'lib/chosen.dart');
      expect(change.dir, 'lib/');
      expect(change.displayName, 'chosen.dart');
      expect(change.operationLabel, 'modify');
      expect(change.changeData, {
        'modify': {'oldText': 'before', 'newText': 'after'},
      });
    });

    test('source order selects the first structured changes envelope', () {
      Map<String, dynamic> envelope(String path) => {
        'changes': {
          path: {'content': path},
        },
      };
      final patch = CodexPatchData.fromTool({
        'input': envelope('input.dart'),
        'content': envelope('content.dart'),
        'raw': envelope('raw.dart'),
        'result': envelope('result.dart'),
      });

      expect(patch.fileChanges.single.path, 'input.dart');
      expect(patch.autoApproved, isNull);
    });

    test('invalid structured entries fall back to a nested patch body', () {
      final patch = CodexPatchData.fromTool({
        'input': {
          'changes': [null, 2, 'invalid', <String, dynamic>{}],
        },
        'raw': {
          'arguments': [
            {
              'body':
                  '*** Begin Patch\n*** Delete File: old.dart\n'
                  '*** End Patch',
            },
          ],
        },
      });

      final change = patch.fileChanges.single;
      expect(change.path, 'old.dart');
      expect(change.hasDelete, isTrue);
      expect(change.hasAdd, isFalse);
      expect(change.hasModify, isFalse);
      expect(change.changeData, {
        'delete': {'patch': '*** Delete File: old.dart'},
      });
    });

    test('patch sections retain operation, order, and move lines', () {
      final patch = CodexPatchData.fromTool({
        'input': '''
*** Begin Patch
*** Add File: new.dart
+new content
*** Update File: old.dart
*** Move to: moved.dart
@@
-old
+new
*** Delete File: removed.dart
*** End Patch
''',
      });

      expect(patch.fileChanges.map((change) => change.path), [
        'new.dart',
        'old.dart',
        'removed.dart',
      ]);
      expect(patch.fileChanges.map((change) => change.operationLabel), [
        'add',
        'modify',
        'delete',
      ]);
      expect(patch.fileChanges[0].changeData, {
        'add': {'patch': '*** Add File: new.dart\n+new content'},
      });
      expect(patch.fileChanges[1].changeData, {
        'modify': {
          'patch':
              '*** Update File: old.dart\n*** Move to: moved.dart\n'
              '@@\n-old\n+new',
        },
      });
      expect(patch.fileChanges[2].changeData, {
        'delete': {'patch': '*** Delete File: removed.dart'},
      });
    });

    test('a patch without recognized file headers retains its raw content', () {
      const body = '*** Begin Patch\n@@\n-old\n+new\n*** End Patch\n';
      final patch = CodexPatchData.fromTool({'result': body});

      final change = patch.fileChanges.single;
      expect(change.path, 'patch');
      expect(change.dir, isEmpty);
      expect(change.displayName, 'patch');
      expect(change.operationLabel, 'modify');
      expect(change.changeData, {
        'modify': {'patch': body},
      });
    });

    test('normalizes mixed operations without changing the provider map', () {
      final source = <String, dynamic>{
        'path': 'lib/mixed.dart',
        'kind': 'deleted',
        'created': {'content': 'created'},
        'EDITED': {'diff': '-before\n+after'},
        'removed': 'removed',
      };
      final patch = CodexPatchData.fromTool({
        'input': {'changes': source},
      });

      final change = patch.fileChanges.single;
      expect(change.hasAdd, isTrue);
      expect(change.hasModify, isTrue);
      expect(change.hasDelete, isTrue);
      expect(change.operationLabel, 'add, modify, delete');
      expect(change.changeData, {
        'add': {'content': 'created'},
        'modify': {'diff': '-before\n+after'},
        'delete': {'content': 'removed'},
      });
      expect(source, {
        'path': 'lib/mixed.dart',
        'kind': 'deleted',
        'created': {'content': 'created'},
        'EDITED': {'diff': '-before\n+after'},
        'removed': 'removed',
      });
    });

    test('list changes skip invalid paths while preserving valid entries', () {
      final patch = CodexPatchData.fromTool({
        'input': {
          'changes': [
            null,
            {'path': '', 'kind': 'add', 'content': 'invalid'},
            {'file_path': 'lib/valid.dart', 'action': 'created', 'text': 'ok'},
            {'kind': 'deleted'},
          ],
        },
      });

      final change = patch.fileChanges.single;
      expect(change.path, 'lib/valid.dart');
      expect(change.operationLabel, 'add');
      expect(change.changeData, {
        'add': {'text': 'ok'},
      });
    });

    test('path maps recover patch text from nested lists, not metadata', () {
      final patch = CodexPatchData.fromTool({
        'input': {
          'changes': {
            'lib/fallback.dart': {
              'kind': 'provider-specific',
              'output': [
                {'text': '-before'},
                {'body': '+after'},
              ],
            },
          },
        },
      });

      final change = patch.fileChanges.single;
      expect(change.operationLabel, 'modify');
      expect(change.changeData['modify']['patch'], '-before\n+after');
    });

    test('unrecognized payloads produce no file changes', () {
      final patch = CodexPatchData.fromTool({
        'input': {'auto_approved': false, 'body': 'ordinary output'},
        'result': [null, false, 42],
      });

      expect(patch.fileChanges, isEmpty);
      expect(patch.autoApproved, isFalse);
    });
  });
}
