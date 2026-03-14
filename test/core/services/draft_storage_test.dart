import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DraftStateTransition', () {
    group('isStateTransition', () {
      test('returns true when going from empty to non-empty', () {
        expect(
          DraftStateTransition.isStateTransition('', 'hello'),
          isTrue,
        );
      });

      test('returns true when going from non-empty to empty', () {
        expect(
          DraftStateTransition.isStateTransition('hello', ''),
          isTrue,
        );
      });

      test('returns true with whitespace-only to non-empty', () {
        expect(
          DraftStateTransition.isStateTransition('   ', 'hello'),
          isTrue,
        );
      });

      test('returns false when both empty', () {
        expect(
          DraftStateTransition.isStateTransition('', ''),
          isFalse,
        );
      });

      test('returns false when both non-empty', () {
        expect(
          DraftStateTransition.isStateTransition('hello', 'world'),
          isFalse,
        );
      });

      test('returns false when both whitespace-only', () {
        expect(
          DraftStateTransition.isStateTransition('  ', '\t\n'),
          isFalse,
        );
      });
    });

    group('becameEmpty', () {
      test('returns true when text cleared', () {
        expect(
          DraftStateTransition.becameEmpty('hello', ''),
          isTrue,
        );
      });

      test('returns true when text cleared to whitespace', () {
        expect(
          DraftStateTransition.becameEmpty('hello', '   '),
          isTrue,
        );
      });

      test('returns false when already empty', () {
        expect(
          DraftStateTransition.becameEmpty('', ''),
          isFalse,
        );
      });

      test('returns false when going from empty to non-empty', () {
        expect(
          DraftStateTransition.becameEmpty('', 'hello'),
          isFalse,
        );
      });

      test('returns false when both non-empty', () {
        expect(
          DraftStateTransition.becameEmpty('a', 'b'),
          isFalse,
        );
      });
    });

    group('becameNonEmpty', () {
      test('returns true when text added to empty', () {
        expect(
          DraftStateTransition.becameNonEmpty('', 'hello'),
          isTrue,
        );
      });

      test('returns true when text added to whitespace-only', () {
        expect(
          DraftStateTransition.becameNonEmpty('   ', 'hello'),
          isTrue,
        );
      });

      test('returns false when already non-empty', () {
        expect(
          DraftStateTransition.becameNonEmpty('hello', 'world'),
          isFalse,
        );
      });

      test('returns false when going from non-empty to empty', () {
        expect(
          DraftStateTransition.becameNonEmpty('hello', ''),
          isFalse,
        );
      });

      test('returns false when both empty', () {
        expect(
          DraftStateTransition.becameNonEmpty('', ''),
          isFalse,
        );
      });
    });
  });

  group('DraftAutoSave', () {
    late List<String> savedDrafts;
    late DraftAutoSave autoSave;

    setUp(() {
      savedDrafts = [];
      autoSave = DraftAutoSave(
        sessionId: 'test-session',
        onSave: (draft) => savedDrafts.add(draft),
        debounceDuration: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      autoSave.dispose();
    });

    test('does not save immediately on update', () {
      autoSave.update('Hello');

      expect(savedDrafts, isEmpty);
    });

    test('saves after debounce duration', () async {
      autoSave.update('Hello');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, equals(['Hello']));
    });

    test('debounces multiple rapid updates', () async {
      autoSave.update('H');
      autoSave.update('He');
      autoSave.update('Hel');
      autoSave.update('Hell');
      autoSave.update('Hello');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Only the last update should be saved
      expect(savedDrafts, equals(['Hello']));
    });

    test('saveNow saves immediately without waiting', () {
      autoSave.update('Immediate');
      autoSave.saveNow();

      expect(savedDrafts, equals(['Immediate']));
    });

    test('saveNow clears pending draft', () async {
      autoSave.update('First');
      autoSave.saveNow();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should only save once
      expect(savedDrafts, equals(['First']));
    });

    test('saveNow does nothing when no pending draft', () {
      autoSave.saveNow();

      expect(savedDrafts, isEmpty);
    });

    test('saveNow does not save empty draft', () {
      autoSave.update('');
      autoSave.saveNow();

      expect(savedDrafts, isEmpty);
    });

    test('dispose cancels pending save', () async {
      autoSave.update('Pending');
      autoSave.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, isEmpty);
    });

    test('update after saveNow starts new debounce', () async {
      autoSave.update('First');
      autoSave.saveNow();

      autoSave.update('Second');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, equals(['First', 'Second']));
    });

    test('empty draft is not saved after debounce', () async {
      autoSave.update('');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, isEmpty);
    });

    test('sessionId can be changed', () {
      autoSave.sessionId = 'new-session';
      expect(autoSave.sessionId, equals('new-session'));
    });
  });

  group('DraftAutoSave', () {
    late List<String> savedDrafts;
    late DraftAutoSave controller;

    setUp(() {
      savedDrafts = [];
      controller = DraftAutoSave(
        sessionId: 'ctrl-session',
        onSave: (draft) => savedDrafts.add(draft),
        debounceDuration: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('update triggers debounced save', () async {
      controller.update('Test draft');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, equals(['Test draft']));
    });

    test('saveNow saves immediately', () {
      controller.update('Now');
      controller.saveNow();

      expect(savedDrafts, equals(['Now']));
    });

    test('dispose cancels pending saves', () async {
      controller.update('Pending');
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(savedDrafts, isEmpty);
    });

    test('sessionId is mutable', () {
      controller.sessionId = 'updated-id';
      expect(controller.sessionId, equals('updated-id'));
    });
  });

  group('DraftStateTransition', () {
    test('isStateTransition delegates correctly', () {
      expect(DraftStateTransition.isStateTransition('', 'text'), isTrue);
      expect(DraftStateTransition.isStateTransition('text', 'more'), isFalse);
    });

    test('becameEmpty delegates correctly', () {
      expect(DraftStateTransition.becameEmpty('text', ''), isTrue);
      expect(DraftStateTransition.becameEmpty('', 'text'), isFalse);
    });

    test('becameNonEmpty delegates correctly', () {
      expect(DraftStateTransition.becameNonEmpty('', 'text'), isTrue);
      expect(DraftStateTransition.becameNonEmpty('text', ''), isFalse);
    });
  });
}
