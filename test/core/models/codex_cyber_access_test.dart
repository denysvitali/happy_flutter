import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/codex_cyber_access.dart';
import 'package:happy_flutter/core/models/session.dart';

void main() {
  group('CodexCyberAccess', () {
    test('parses the status happy-cli-go publishes', () {
      final access = CodexCyberAccess.maybeFromJson({
        'requested': 'daybreak_blue',
        'state': 'active',
        'model': 'gpt-6.1-sol',
        'available': ['standard', 'daybreak_blue'],
        'supported': true,
        'lastFlaggedAt': 1794904355652,
        'detail': 'daybreak_blue is requested on every turn',
        'updatedAt': 1794904355700,
      })!;
      expect(access.state, CodexCyberAccessState.active);
      expect(access.isActive, isTrue);
      expect(access.eligible, isTrue);
      expect(access.requested, 'daybreak_blue');
      expect(access.available, ['standard', 'daybreak_blue']);
      expect(access.lastFlaggedAt, 1794904355652);
      expect(CodexCyberAccess.maybeFromJson(access.toJson()), access);
    });

    test('keeps unknown availability distinct from none', () {
      final unknown = CodexCyberAccess.maybeFromJson({'state': 'requested'})!;
      expect(unknown.available, isNull);
      expect(unknown.eligible, isFalse);
      final none = CodexCyberAccess.maybeFromJson({
        'state': 'unavailable',
        'available': <String>[],
      })!;
      expect(none.available, isEmpty);
    });

    test('automatic selection reads as off, unknown states stay unknown', () {
      final off = CodexCyberAccess.maybeFromJson({
        'requested': '',
        'state': 'off',
      })!;
      expect(off.state, CodexCyberAccessState.off);
      expect(off.isActive, isFalse);
      expect(
        CodexCyberAccess.maybeFromJson({'state': 'future'})!.state,
        CodexCyberAccessState.unknown,
      );
      expect(CodexCyberAccess.maybeFromJson('garbage'), isNull);
    });

    test('is read from session metadata', () {
      final metadata = Metadata.fromJson({
        'flavor': 'codex',
        'codexCyberAccess': {'requested': '', 'state': 'off'},
      });
      expect(metadata.codexCyberAccess?.state, CodexCyberAccessState.off);
      expect(Metadata.fromJson({'flavor': 'codex'}).codexCyberAccess, isNull);
    });
  });
}
