import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_helpers.dart';
import 'package:happy_flutter/features/chat/tools/views/mcp_result_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mcpResultSummary', () {
    test('counts array items', () {
      expect(
        mcpResultSummary('["ant-codex","happy-cli","happy-daemon"]'),
        '3 items',
      );
      expect(mcpResultSummary('["only"]'), '1 item');
    });

    test('prefers the payload list of an envelope object', () {
      expect(
        mcpResultSummary('{"limit":0,"offset":0,"traces":[{"a":1},{"b":2}]}'),
        '2 traces',
      );
    });

    test('falls back to field count for plain objects', () {
      expect(mcpResultSummary('{"a":1,"b":2}'), '2 fields');
    });

    test('counts lines for non-JSON text and skips single lines', () {
      expect(mcpResultSummary('one\ntwo\nthree'), '3 lines');
      expect(mcpResultSummary('just a sentence'), isNull);
      expect(mcpResultSummary(''), isNull);
    });
  });

  group('tryDecodeJsonCollection', () {
    test('returns null for scalars and malformed input', () {
      expect(tryDecodeJsonCollection('42'), isNull);
      expect(tryDecodeJsonCollection('"quoted"'), isNull);
      expect(tryDecodeJsonCollection('{oops'), isNull);
      expect(tryDecodeJsonCollection(''), isNull);
    });

    test('decodes objects and arrays', () {
      expect(tryDecodeJsonCollection('{"a":1}'), isA<Map<String, dynamic>>());
      expect(tryDecodeJsonCollection(' [1,2] '), isA<List<dynamic>>());
    });
  });

  group('McpResultView', () {
    testWidgets('pretty-prints a single-line JSON payload', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const McpResultView(
            text: '{"limit":0,"total":0,"traces":[{"id":"abc"}]}',
          ),
        ),
      );

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      final rendered = text.data!;
      expect(rendered, contains('\n'));
      expect(rendered, contains('"limit": 0'));
      expect(find.textContaining('JSON'), findsOneWidget);
    });

    testWidgets('labels non-JSON output and keeps it verbatim', (tester) async {
      await tester.pumpWidget(_wrap(const McpResultView(text: 'plain output')));

      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        'plain output',
      );
      expect(find.textContaining('OUTPUT'), findsOneWidget);
    });

    testWidgets('truncates long output and expands on Show more', (
      tester,
    ) async {
      final long = List<String>.generate(40, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(McpResultView(text: long, collapsedMaxLines: 5)),
      );

      var rendered = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(rendered.split('\n').length, 5);
      expect(find.text('Show 35 more lines'), findsOneWidget);

      await tester.tap(find.text('Show 35 more lines'));
      await tester.pumpAndSettle();

      rendered = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(rendered.split('\n').length, 40);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('short output shows no Show more row', (tester) async {
      await tester.pumpWidget(_wrap(const McpResultView(text: 'a\nb')));
      expect(find.textContaining('Show'), findsNothing);
    });
  });
}
