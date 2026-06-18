import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

void main() {
  group('DiffTheme default constructor', () {
    // The legacy `DiffTheme()` default ctor is no longer used by any
    // production caller (they route through DiffTheme.light from the
    // ThemeExtension in core/theme/diff_theme.dart, or through the
    // asLegacy() bridge). But its public constructor signature is
    // still part of the API surface, and the default values must
    // match the canonical palette so any future caller gets correct
    // values. This test pins that the defaults agree with the
    // AppColors.diff*Light tokens.
    test('default addedBg matches the canonical light token', () {
      const t = DiffTheme();
      expect(t.addedBg, const Color(0xFFE6FFEC));
    });

    test('default removedBg matches the canonical light token', () {
      const t = DiffTheme();
      expect(t.removedBg, const Color(0xFFFFEBE9));
    });

    test('default addedText / removedText match the canonical light tokens', () {
      const t = DiffTheme();
      expect(t.addedText, const Color(0xFF1A7F37));
      expect(t.removedText, const Color(0xFFCF222E));
    });

    test('default hunkHeader / lineNumber bg + text match the canonical tokens',
        () {
      const t = DiffTheme();
      expect(t.lineNumberBg, const Color(0xFFF5F5F5));
      expect(t.lineNumberText, const Color(0xFF6E7781));
      expect(t.hunkHeaderBg, const Color(0xFFF0F0F0));
      expect(t.hunkHeaderText, const Color(0xFF656D76));
    });

    test('default inlineAdded / inlineRemoved use the translucent light hexes',
        () {
      const t = DiffTheme();
      expect(t.inlineAddedBg, const Color(0x4AC26B4D));
      // Post-batch 4 fix: inlineRemovedBg is no longer olive
      // (#A39E4D). It must be a translucent red so Edit and
      // MultiEdit tool outputs render the removed highlight in red.
      expect(t.inlineRemovedBg, const Color(0x4ACF222E));
    });

    test('default leadingSpaceDot matches the canonical light token', () {
      const t = DiffTheme();
      expect(t.leadingSpaceDot, const Color(0xFFD4D4D4));
    });

    test('default contextBg is transparent (used as the unchanged-line bg)',
        () {
      const t = DiffTheme();
      expect(t.contextBg.a, lessThanOrEqualTo(0.0));
    });

    test('default contextText matches the canonical light token', () {
      const t = DiffTheme();
      expect(t.contextText, const Color(0xFF24292F));
    });
  });
}
