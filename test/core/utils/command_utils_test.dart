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

    test('removes the plain sh wrapper from multiline commands', () {
      const wrapped = r'''/bin/sh -c "tail -100 drivers/iommu/mtk_iommu.c
rg -n \"subsys_initcall|postcore_initcall|arch_initcall\" drivers/iommu
rg -n \"#define subsys_initcall|module_init\\(\" include/linux/init.h"''';
      const expected = r'''tail -100 drivers/iommu/mtk_iommu.c
rg -n "subsys_initcall|postcore_initcall|arch_initcall" drivers/iommu
rg -n "#define subsys_initcall|module_init\(" include/linux/init.h''';

      expect(cleanShellCommand(wrapped), expected);
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
