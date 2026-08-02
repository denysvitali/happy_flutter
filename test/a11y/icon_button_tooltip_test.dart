import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

/// Returns the source range of the balanced `(...)` starting at [open].
String _balanced(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}

/// Every `IconButton(` in `lib/` must name its action, either through its own
/// `tooltip:` argument or through an enclosing `Tooltip` / `Semantics`.
List<String> _iconButtonsWithoutAccessibleName() {
  final offenders = <String>[];
  final lib = Directory('lib');
  final pattern = RegExp(r'IconButton\(');

  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    final lines = source.split('\n');

    for (final match in pattern.allMatches(source)) {
      final body = _balanced(source, match.end - 1);
      if (body.contains('tooltip:')) continue;

      final lineIndex = '\n'.allMatches(
        source.substring(0, match.start),
      ).length;
      final start = lineIndex - 4 < 0 ? 0 : lineIndex - 4;
      final context = lines.sublist(start, lineIndex).join('\n');
      if (context.contains('Tooltip(') || context.contains('Semantics(')) {
        continue;
      }
      offenders.add('${entity.path}:${lineIndex + 1}');
    }
  }
  return offenders;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('icon-only buttons expose an accessible name', () {
    test('no IconButton in lib/ is missing a tooltip', () {
      final offenders = _iconButtonsWithoutAccessibleName();
      expect(
        offenders,
        isEmpty,
        reason:
            'IconButtons without a tooltip (or enclosing Tooltip/Semantics) '
            'have no accessible name:\n${offenders.join('\n')}',
      );
    });

    testWidgets('ToolViewCopyButton names the copy action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ToolViewCopyButton(text: 'payload'),
          ),
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
    });
  });
}
