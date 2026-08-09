import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_helpers.dart';
import 'package:happy_flutter/features/chat/tools/views/mcp_result_view.dart';

/// Text shown by the one [SelectableText] in the pane, whether it is rendering
/// plain output or highlighted JSON spans.
String _renderedText(WidgetTester tester) {
  final widget = tester.widget<SelectableText>(find.byType(SelectableText));
  return widget.data ?? widget.textSpan!.toPlainText();
}

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
    testWidgets('renders a JSON payload as a collapsible tree', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const McpResultView(
            text: '{"limit":0,"total":0,"traces":[{"id":"abc"}]}',
          ),
        ),
      );

      expect(find.byType(JsonTreeViewer), findsOneWidget);
      expect(find.textContaining('JSON'), findsOneWidget);
      expect(
        find.textContaining('"limit"', findRichText: true),
        findsOneWidget,
      );
      // The nested array is expanded, so its leaf is visible up front.
      expect(find.textContaining('"abc"', findRichText: true), findsOneWidget);
    });

    testWidgets('collapses and re-expands a JSON node on tap', (tester) async {
      await tester.pumpWidget(
        _wrap(const McpResultView(text: '{"traces":[{"id":"abc"}]}')),
      );

      // Tapping the array's opening bracket row collapses it to a summary.
      await tester.tap(find.textContaining('"traces"', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('"abc"', findRichText: true), findsNothing);
      expect(find.textContaining('1 item', findRichText: true), findsOneWidget);

      await tester.tap(find.textContaining('1 item', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('"abc"', findRichText: true), findsOneWidget);
    });

    testWidgets('renders non-JSON output without span styling', (tester) async {
      await tester.pumpWidget(_wrap(const McpResultView(text: 'a: 1\nb: 2')));

      final widget = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(widget.data, 'a: 1\nb: 2');
      expect(widget.textSpan, isNull);
    });

    testWidgets('labels non-JSON output and keeps it verbatim', (tester) async {
      await tester.pumpWidget(_wrap(const McpResultView(text: 'plain output')));

      expect(_renderedText(tester), 'plain output');
      expect(find.textContaining('OUTPUT'), findsOneWidget);
    });

    testWidgets('truncates long output and expands on Show more', (
      tester,
    ) async {
      final long = List<String>.generate(40, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(McpResultView(text: long, collapsedMaxLines: 5)),
      );

      var rendered = _renderedText(tester);
      expect(rendered.split('\n').length, 5);
      expect(find.text('Show 35 more lines'), findsOneWidget);

      await tester.tap(find.text('Show 35 more lines'));
      await tester.pumpAndSettle();

      rendered = _renderedText(tester);
      expect(rendered.split('\n').length, 40);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('short output shows no Show more row', (tester) async {
      await tester.pumpWidget(_wrap(const McpResultView(text: 'a\nb')));
      expect(find.textContaining('Show'), findsNothing);
    });
  });
}
