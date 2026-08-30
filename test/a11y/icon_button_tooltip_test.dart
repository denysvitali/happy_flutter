// Regression guard for the icon-only-button accessibility sweep.
//
// Scope is deliberately an explicit, checked-in list of the sources the
// sweep audited (`_auditedSources`) rather than the whole `lib/` tree.
// A tree-wide scan turns every unrelated new IconButton written by
// someone else into a red build in this file, which is not a signal
// anyone can act on here. Adding a source to the list is the way to
// extend the guard.
//
// Two shapes are checked in each audited source:
//   1. `IconButton(` — must carry `tooltip:` or sit inside a `Tooltip(`
//      / `Semantics(` wrapper.
//   2. icon-only `InkWell(` / `GestureDetector(` tap targets — a tap
//      target whose subtree renders an `Icon` and no `Text` has no
//      accessible name of its own, so it must be wrapped too.
//
// Containment is decided by balanced-paren ranges, not by "look at the
// four lines above", so a wrapper any distance up the tree counts.

import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Sources covered by the icon-only accessibility sweep.
const _auditedSources = <String>[
  'lib/core/components/sidebar_view.dart',
  'lib/core/components/tool_view_buttons.dart',
  'lib/features/auth/auth_screen.dart',
  'lib/features/auth/widgets/auth_animated_widgets.dart',
  'lib/features/auth/widgets/auth_landing_widgets.dart',
  'lib/features/chat/tools/views/web_fetch_view.dart',
  'lib/features/chat/widgets/scroll_to_bottom_pill.dart',
  'lib/features/chat/widgets/session_tasks_banner.dart',
  'lib/features/chat/widgets/thinking_block.dart',
  'lib/features/dev/notification_test_screen.dart',
  'lib/features/sandbox/sandbox_screen.dart',
  'lib/features/settings/account_screen.dart',
  'lib/features/settings/link_device_screen.dart',
  'lib/features/settings/linked_devices_screen.dart',
  'lib/features/settings/machines_screen.dart',
  'lib/features/settings/profile_wizard_screen.dart',
  'lib/features/settings/profiles_screen.dart',
  'lib/features/settings/restore_account_screen.dart',
  'lib/features/settings/server_settings_screen.dart',
  'lib/features/settings/voice_settings_screen.dart',
  'lib/features/sftp/screens/sftp_directory_manager_screen.dart',
  'lib/features/sftp/screens/sftp_log_viewer_screen.dart',
];

/// End offset (exclusive) of the balanced `(...)` opening at [open].
int _balancedEnd(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return source.length;
}

/// Ranges of every `Tooltip(` / `Semantics(` constructor in [source].
List<List<int>> _wrapperRanges(String source) {
  final ranges = <List<int>>[];
  final pattern = RegExp(r'\b(Tooltip|Semantics)\(');
  for (final match in pattern.allMatches(source)) {
    final open = match.end - 1;
    ranges.add(<int>[match.start, _balancedEnd(source, open)]);
  }
  return ranges;
}

bool _insideWrapper(List<List<int>> ranges, int start, int end) {
  for (final range in ranges) {
    // A strict wrapper starts before the target and closes after it.
    if (range[0] < start && range[1] >= end) return true;
  }
  return false;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

/// Offenders in one source file, formatted `path:line (reason)`.
List<String> _offendersIn(String path, String source) {
  final offenders = <String>[];
  final wrappers = _wrapperRanges(source);

  for (final match in RegExp(r'\bIconButton\(').allMatches(source)) {
    final open = match.end - 1;
    final end = _balancedEnd(source, open);
    final body = source.substring(open, end);
    if (body.contains('tooltip:')) continue;
    if (_insideWrapper(wrappers, match.start, end)) continue;
    offenders.add('$path:${_lineOf(source, match.start)} (IconButton)');
  }

  final tapTarget = RegExp(r'\b(InkWell|GestureDetector)\(');
  for (final match in tapTarget.allMatches(source)) {
    final open = match.end - 1;
    final end = _balancedEnd(source, open);
    final body = source.substring(open, end);
    // Only icon-only targets are nameless: anything rendering text
    // already exposes that text as its accessible name.
    if (!body.contains('Icon(')) continue;
    if (body.contains('Text(')) continue;
    if (body.contains('Semantics(') || body.contains('Tooltip(')) continue;
    if (_insideWrapper(wrappers, match.start, end)) continue;
    final kind = match.group(1);
    offenders.add('$path:${_lineOf(source, match.start)} ($kind, icon-only)');
  }

  return offenders;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('icon-only buttons expose an accessible name', () {
    test('every audited source still exists', () {
      final missing = _auditedSources
          .where((path) => !File(path).existsSync())
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'These files moved or were deleted; update _auditedSources '
            'so the guard keeps covering them:\n${missing.join('\n')}',
      );
    });

    test('no audited icon-only target is missing an accessible name', () {
      final offenders = <String>[];
      for (final path in _auditedSources) {
        final file = File(path);
        if (!file.existsSync()) continue;
        offenders.addAll(_offendersIn(path, file.readAsStringSync()));
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Icon-only tap targets without a tooltip (or enclosing '
            'Tooltip/Semantics) have no accessible name:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the scanner flags an unwrapped icon-only tap target', () {
      const sample = '''
Widget build(BuildContext context) {
  return Row(children: [
    IconButton(icon: const Icon(Icons.add), onPressed: () {}),
    InkWell(onTap: () {}, child: const Icon(Icons.close)),
    Tooltip(
      message: 'ok',
      child: InkWell(onTap: () {}, child: const Icon(Icons.done)),
    ),
    IconButton(
      tooltip: 'named',
      icon: const Icon(Icons.edit),
      onPressed: () {},
    ),
  ]);
}
''';
      final offenders = _offendersIn('sample.dart', sample);
      expect(offenders, hasLength(2));
      expect(offenders.first, contains('IconButton'));
      expect(offenders.last, contains('icon-only'));
    });

    testWidgets('ToolViewCopyButton names the copy action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ToolViewCopyButton(text: 'payload')),
        ),
      );
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byIcon(Icons.copy),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Copy');
      final targetSize = tester.getSize(find.byType(ToolViewCopyButton));
      expect(targetSize.width, greaterThanOrEqualTo(AppTouchTarget.min));
      expect(targetSize.height, greaterThanOrEqualTo(AppTouchTarget.min));
    });

    testWidgets('ToolViewShowMoreButton exposes state and a 44dp target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ToolViewShowMoreButton(
              expanded: false,
              hiddenCount: 3,
              onToggle: () {},
            ),
          ),
        ),
      );

      final finder = find.byType(ToolViewShowMoreButton);
      final node = tester.getSemantics(finder);
      expect(node.label, 'Show 3 more lines');
      expect(node.flagsCollection.isExpanded, Tristate.isFalse);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });
  });
}
