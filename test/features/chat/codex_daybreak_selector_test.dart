import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/codex_cyber_access.dart';
import 'package:happy_flutter/core/services/codex_daybreak_selection.dart';
import 'package:happy_flutter/features/chat/widgets/codex_daybreak_selector.dart';

CodexCyberAccess _status(String requested, String source) => CodexCyberAccess(
  state: requested.startsWith('daybreak')
      ? CodexCyberAccessState.active
      : CodexCyberAccessState.off,
  requested: requested,
  source: source,
);

void main() {
  group('CodexDaybreakChoice', () {
    test('wire values match happy-cli-go selections', () {
      expect(CodexDaybreakChoice.values.map((c) => c.wire), [
        'machine',
        'auto',
        'daybreak_blue',
        'daybreak_red',
        'standard',
      ]);
      expect(CodexDaybreakChoice.fromWire('auto'), CodexDaybreakChoice.off);
      expect(CodexDaybreakChoice.fromWire('bogus'), isNull);
      expect(CodexDaybreakChoice.fromProgram(''), CodexDaybreakChoice.off);
    });
  });

  group('codexDaybreakOutgoingChoice', () {
    test('a saved choice always wins', () {
      expect(
        codexDaybreakOutgoingChoice(
          saved: CodexDaybreakChoice.red,
          daybreakByDefault: true,
          status: null,
        ),
        CodexDaybreakChoice.red,
      );
    });

    test('the default requests Blue until the session has its own choice', () {
      expect(
        codexDaybreakOutgoingChoice(
          saved: null,
          daybreakByDefault: true,
          status: _status('', 'machine'),
        ),
        CodexDaybreakChoice.blue,
      );
      expect(
        codexDaybreakOutgoingChoice(
          saved: null,
          daybreakByDefault: true,
          status: _status('', 'session'),
        ),
        isNull,
      );
      expect(
        codexDaybreakOutgoingChoice(
          saved: null,
          daybreakByDefault: false,
          status: null,
        ),
        isNull,
      );
    });
  });

  group('codexDaybreakChoiceApplied', () {
    test('compares the choice with what the session reports', () {
      expect(
        codexDaybreakChoiceApplied(
          CodexDaybreakChoice.blue,
          _status('daybreak_blue', 'session'),
        ),
        isTrue,
      );
      expect(
        codexDaybreakChoiceApplied(
          CodexDaybreakChoice.blue,
          _status('daybreak_blue', 'machine'),
        ),
        isFalse,
      );
      expect(
        codexDaybreakChoiceApplied(
          CodexDaybreakChoice.machine,
          _status('', 'machine'),
        ),
        isTrue,
      );
      expect(
        codexDaybreakChoiceApplied(CodexDaybreakChoice.off, null),
        isFalse,
      );
    });
  });
}
