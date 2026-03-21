import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/permission_description.dart';

void main() {
  group('describePermissionAction', () {
    test('returns generic run when toolInput is null', () {
      expect(
        describePermissionAction('Bash', null),
        'run Bash',
      );
    });

    test('describes Edit with path', () {
      expect(
        describePermissionAction('Edit', {'path': 'src/main.dart'}),
        'edit src/main.dart',
      );
    });

    test('truncates long Edit paths', () {
      final longPath = 'a' * 50;
      final result = describePermissionAction('Edit', {'path': longPath});
      expect(result, startsWith('edit ...'));
      expect(result.length, lessThanOrEqualTo(42 + 5));
    });

    test('describes Edit without path', () {
      expect(
        describePermissionAction('Edit', <String, dynamic>{}),
        'edit file',
      );
    });

    test('describes MultiEdit with path', () {
      expect(
        describePermissionAction(
          'MultiEdit',
          {'path': 'lib/foo.dart'},
        ),
        'edit lib/foo.dart',
      );
    });

    test('describes NotebookEdit with path', () {
      expect(
        describePermissionAction(
          'NotebookEdit',
          {'path': 'notebook.ipynb'},
        ),
        'edit notebook.ipynb',
      );
    });

    test('describes Write with path', () {
      expect(
        describePermissionAction(
          'Write',
          {'path': 'new_file.dart'},
        ),
        'write new_file.dart',
      );
    });

    test('describes Write without path', () {
      expect(
        describePermissionAction('Write', <String, dynamic>{}),
        'write file',
      );
    });

    test('describes Bash with command', () {
      expect(
        describePermissionAction(
          'Bash',
          {'command': 'git status'},
        ),
        'run: git status',
      );
    });

    test('truncates long Bash commands', () {
      final longCmd = 'a' * 60;
      final result = describePermissionAction(
        'Bash',
        {'command': longCmd},
      );
      expect(result, startsWith('run: '));
      // 42 chars + ellipsis
      expect(result, contains('\u2026'));
    });

    test('describes Bash without command', () {
      expect(
        describePermissionAction('Bash', <String, dynamic>{}),
        'run bash command',
      );
    });

    test('describes ExitPlanMode', () {
      expect(
        describePermissionAction(
          'ExitPlanMode',
          <String, dynamic>{},
        ),
        'accept plan and continue',
      );
    });

    test('describes exit_plan_mode (snake_case variant)', () {
      expect(
        describePermissionAction(
          'exit_plan_mode',
          <String, dynamic>{},
        ),
        'accept plan and continue',
      );
    });

    test('describes unknown tool', () {
      expect(
        describePermissionAction(
          'CustomTool',
          {'key': 'value'},
        ),
        'run CustomTool',
      );
    });
  });
}
