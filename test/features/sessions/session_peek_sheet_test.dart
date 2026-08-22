import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/session_peek_sheet.dart';

/// The peek sheet renders whatever the message cache already holds —
/// no fetches, no navigation. These tests pin the extraction rules that
/// decide what a glanceable bubble is.
void main() {
  Map<String, dynamic> msg(
    String role,
    String text, {
    bool sidechain = false,
    bool thinking = false,
    bool error = false,
    String? kind,
    String? errorMessage,
  }) => {
    'role': role,
    'content': text,
    if (sidechain) 'isSidechain': true,
    if (thinking) 'isThinking': true,
    if (error) 'isError': true,
    if (error) 'errorMessage': errorMessage ?? text,
    if (kind != null) 'kind': kind,
  };

  group('extractPeekBubbles', () {
    test('keeps user and agent prose in order', () {
      final items = extractPeekBubbles([
        msg('user', 'fix the bug'),
        msg('agent', 'On it — reading the parser now.'),
      ]);
      expect(items, hasLength(2));
      expect(items.first.role, 'user');
      expect(items.last.role, 'agent');
    });

    test('skips sidechains, thinking rows and agent events', () {
      final items = extractPeekBubbles([
        msg('agent', 'background thought', thinking: true),
        msg('agent', 'sidechain work', sidechain: true),
        msg('agent', '', kind: 'agent-event'),
        msg('user', 'visible'),
      ]);
      expect(items, hasLength(1));
      expect(items.single.text, 'visible');
    });

    test('renders errors from the error field as error bubbles', () {
      final items = extractPeekBubbles([
        msg('agent', '', error: true, errorMessage: 'API Error: overloaded'),
      ]);
      expect(items.single.isError, isTrue);
      expect(items.single.text, 'API Error: overloaded');
    });

    test('summarizes tool calls instead of dumping payloads', () {
      final items = extractPeekBubbles([
        {
          'role': 'agent',
          'kind': 'tool-call',
          'name': 'Bash',
          'input': {'command': 'flutter analyze'},
        },
      ]);
      expect(items, hasLength(1));
      expect(items.single.isTool, isTrue);
      expect(items.single.text, contains('Bash'));
      expect(items.single.text, contains('flutter analyze'));
    });

    test('caps at the newest eight bubbles', () {
      final messages = [
        for (var i = 0; i < 20; i++) msg('agent', 'row $i'),
      ];
      final items = extractPeekBubbles(messages);
      expect(items, hasLength(peekMaxBubbles));
      expect(items.first.text, 'row 12');
      expect(items.last.text, 'row 19');
    });
  });

  group('cleanPeekText', () {
    test('collapses fenced code and images to placeholders', () {
      final cleaned = cleanPeekText(
        'before ```dart\nvoid main() {}\n``` middle ![alt](x.png) end',
        maxLen: 500,
      );
      expect(cleaned, isNot(contains('void main')));
      expect(cleaned, contains('[code]'));
      expect(cleaned, contains('[image]'));
    });

    test('truncates with an ellipsis at maxLen', () {
      final cleaned = cleanPeekText('a' * 400, maxLen: 100);
      expect(cleaned.length, 101);
      expect(cleaned.endsWith('…'), isTrue);
    });
  });

  group('peekToolSummary', () {
    test('prefers the first meaningful input key', () {
      final summary = peekToolSummary({
        'name': 'Read',
        'input': {'file_path': '/repo/lib/a.dart'},
      });
      expect(summary, '/repo/lib/a.dart');
    });

    test('falls back to the bare tool name', () {
      expect(peekToolSummary({'name': 'Grep'}), 'Used Grep');
      expect(peekToolSummary({}), isNull);
    });

    test('clamps long targets', () {
      final summary = peekToolSummary({
        'name': 'Bash',
        'input': {'command': 'x' * 200},
      });
      expect(summary!.length, lessThan(120));
      expect(summary.endsWith('…'), isTrue);
    });
  });
}
