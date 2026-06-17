import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/loop_command_parser.dart';

void main() {
  group('LoopCommandParser.parse', () {
    test('parses "5m check the deploy" as a recurring */5 cron', () {
      final req = LoopCommandParser.parse('/loop 5m check the deploy');
      expect(req, isNotNull);
      expect(req!.expression, '*/5 * * * *');
      expect(req.prompt, 'check the deploy');
      expect(req.recurring, isTrue);
    });

    test('parses "1h roll up the standup" as recurring hourly', () {
      final req = LoopCommandParser.parse('/loop 1h roll up the standup');
      expect(req, isNotNull);
      expect(req!.expression, '0 */1 * * *');
      expect(req.prompt, 'roll up the standup');
      expect(req.recurring, isTrue);
    });

    test('parses "2h sync with team" as recurring every 2 hours', () {
      final req = LoopCommandParser.parse('/loop 2h sync with team');
      expect(req, isNotNull);
      expect(req!.expression, '0 */2 * * *');
    });

    test('parses "1d summarize commits" as daily recurring', () {
      final req = LoopCommandParser.parse('/loop 1d summarize today');
      expect(req, isNotNull);
      expect(req!.expression, '0 9 * * *');
      expect(req.recurring, isTrue);
    });

    test('parses "every 30 minutes ping" form', () {
      final req = LoopCommandParser.parse('/loop every 30 minutes ping');
      expect(req, isNotNull);
      expect(req!.expression, '*/30 * * * *');
    });

    test('parses "every 2 hours status" form', () {
      final req = LoopCommandParser.parse('/loop every 2 hours status');
      expect(req, isNotNull);
      expect(req!.expression, '0 */2 * * *');
    });

    test('parses "at 3pm remind me" as one-shot', () {
      final req = LoopCommandParser.parse('/loop at 3pm remind me');
      expect(req, isNotNull);
      expect(req!.recurring, isFalse);
      expect(req.prompt, 'remind me');
    });

    test('parses "tomorrow at 9am standup" as one-shot', () {
      final req = LoopCommandParser.parse('/loop tomorrow at 9am standup');
      expect(req, isNotNull);
      expect(req!.recurring, isFalse);
      expect(req.prompt, 'standup');
    });

    test('returns null when text does not start with /loop', () {
      expect(LoopCommandParser.parse('hello world'), isNull);
      expect(LoopCommandParser.parse('/clear'), isNull);
    });

    test('returns null for "/loop list" (handled separately)', () {
      expect(LoopCommandParser.parse('/loop list'), isNull);
    });

    test('returns null for "/loop cancel <id>" (handled separately)', () {
      expect(LoopCommandParser.parse('/loop cancel abc12345'), isNull);
    });

    test('returns null when interval missing prompt', () {
      expect(LoopCommandParser.parse('/loop 5m'), isNull);
    });

    test('returns null when interval out of range', () {
      expect(LoopCommandParser.parse('/loop 999m nope'), isNull);
      expect(LoopCommandParser.parse('/loop 99h nope'), isNull);
    });

    test('is case-insensitive for "every N minutes" form', () {
      final req = LoopCommandParser.parse('/loop Every 5 Minutes ping');
      expect(req, isNotNull);
      expect(req!.expression, '*/5 * * * *');
    });

    test('handles leading whitespace', () {
      final req = LoopCommandParser.parse('   /loop 5m check   ');
      expect(req, isNotNull);
      expect(req!.prompt, 'check');
    });
  });

  group('LoopCommandParser.matches', () {
    test('matches "/loop" exactly', () {
      expect(LoopCommandParser.matches('/loop'), isTrue);
    });

    test('matches "/loop 5m check"', () {
      expect(LoopCommandParser.matches('/loop 5m check'), isTrue);
    });

    test('matches with leading whitespace', () {
      expect(LoopCommandParser.matches('   /loop 5m check'), isTrue);
    });

    test('does not match unrelated commands', () {
      expect(LoopCommandParser.matches('/clear'), isFalse);
      expect(LoopCommandParser.matches('hello'), isFalse);
      expect(LoopCommandParser.matches(''), isFalse);
    });
  });

  group('LoopCommandParser.parseCancelCommand', () {
    test('parses "/loop cancel abc12345"', () {
      expect(
        LoopCommandParser.parseCancelCommand('/loop cancel abc12345'),
        'abc12345',
      );
    });

    test('returns null for "/loop 5m ping"', () {
      expect(LoopCommandParser.parseCancelCommand('/loop 5m ping'), isNull);
    });

    test('returns null for "/loop cancel" (no id)', () {
      expect(LoopCommandParser.parseCancelCommand('/loop cancel'), isNull);
    });

    test('is case-insensitive on the keyword', () {
      expect(
        LoopCommandParser.parseCancelCommand('/loop Cancel deadbeef'),
        'deadbeef',
      );
    });
  });
}
