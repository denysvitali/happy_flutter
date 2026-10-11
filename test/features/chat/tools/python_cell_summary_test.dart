import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/python_cell_summary.dart';

void main() {
  test(
    'description falls back to first source line, including serialized input',
    () {
      expect(
        pythonCellDescription({
          'input': {'description': 'Inspect files', 'code': 'print(1)'},
        }),
        'Inspect files',
      );
      expect(
        pythonCellDescription({
          'input': r'{"code":"\n# Inspect files\nprint(1)"}',
        }),
        'Inspect files',
      );
      expect(pythonCellDescription({'input': {}}), isNull);
    },
  );

  test('result preview is readable and favors failures over stdout', () {
    expect(
      pythonCellOutputPreview({
        'result': {'stdout': '\nOK\nMore details'},
      }),
      'OK',
    );
    expect(
      pythonCellOutputPreview({
        'state': 'error',
        'result': {
          'stdout': 'Starting',
          'stderr': 'Traceback\nValueError: bad input\n',
        },
      }),
      'ValueError: bad input',
    );
    expect(
      pythonCellOutputPreview({'result': '\x1B[32mOK\x1B[0m\nNext line'}),
      'OK',
    );
    expect(pythonCellOutputPreview({'result': ''}), isNull);
  });

  test('summary truncation preserves emoji', () {
    final output = List.filled(121, '👩🏽‍💻').join();
    expect(
      pythonCellOutputPreview({'result': output}),
      '${List.filled(120, '👩🏽‍💻').join()}…',
    );
  });
}
