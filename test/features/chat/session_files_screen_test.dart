import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/session_files_screen.dart';

void main() {
  test('projects and deduplicates latest file tool operations', () {
    final files = projectSessionFiles([
      {
        'kind': 'tool-call',
        'name': 'Read',
        'input': {'file_path': '/project/lib/../lib/main.dart'},
        'state': 'completed',
      },
      {
        'kind': 'tool-call',
        'name': 'Edit',
        'input': {'filePath': '/project/lib/main.dart'},
        'state': 'running',
      },
      {
        'kind': 'tool-call',
        'name': 'Bash',
        'input': {'file_path': '/ignored'},
      },
    ]);

    expect(files, hasLength(1));
    expect(files.single.path, '/project/lib/main.dart');
    expect(files.single.operation, 'Edit');
    expect(files.single.state, 'running');
  });

  test('ignores malformed file tool payloads', () {
    expect(
      projectSessionFiles([
        {'kind': 'tool-call', 'name': 'Read', 'input': null},
        {
          'kind': 'tool-call',
          'name': 'Write',
          'input': {'path': ''},
        },
      ]),
      isEmpty,
    );
  });
}
