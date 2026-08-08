import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/command_utils.dart';

void main() {
  group('cleanShellCommand', () {
    test('removes Codex sh transport wrapper and outer quotes', () {
      expect(
        cleanShellCommand("/bin/sh -lc 'rg -n TODO lib'"),
        'rg -n TODO lib',
      );
      expect(
        cleanShellCommand('/bin/sh -lc "sed -n \'1,80p\' README.md"'),
        "sed -n '1,80p' README.md",
      );
    });

    test('keeps supporting the bash transport wrapper', () {
      expect(
        cleanShellCommand("/bin/bash -lc 'git status --short'"),
        'git status --short',
      );
    });

    test('leaves ordinary commands unchanged', () {
      expect(
        cleanShellCommand('  mise exec -- flutter analyze  '),
        'mise exec -- flutter analyze',
      );
      expect(cleanShellCommand(null), '');
    });
  });
}
