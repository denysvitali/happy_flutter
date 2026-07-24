import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/task_label.dart';

void main() {
  group('compactTaskLabel', () {
    test('leaves short single-line labels untouched', () {
      expect(compactTaskLabel('exploring repo'), 'exploring repo');
    });

    test('collapses newlines and indentation to single spaces', () {
      const raw = 'cd /repo\npython3 - <<\'PY\'\n    specs = [\n    ]\nPY';
      expect(
        compactTaskLabel(raw),
        "cd /repo python3 - <<'PY' specs = [ ] PY",
      );
    });

    test('clamps long labels with an ellipsis', () {
      final raw = 'a' * 500;
      final label = compactTaskLabel(raw);
      expect(label.length, kMaxTaskLabelChars + 1);
      expect(label.endsWith('…'), true);
    });

    test('honours a custom maxChars', () {
      expect(compactTaskLabel('abcdefghij', maxChars: 4), 'abcd…');
    });

    test('returns empty string for blank input', () {
      expect(compactTaskLabel('   \n\t '), '');
    });
  });
}
