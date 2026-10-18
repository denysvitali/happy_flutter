import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/diff/calculate_diff.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

/// Every line the diff would render, in hunk order.
List<DiffLine> _lines(DiffResult result) =>
    result.hunks.expand((h) => h.lines).toList();

List<DiffLine> _ofType(DiffResult result, DiffLineType type) =>
    _lines(result).where((l) => l.type == type).toList();

/// Text a token list reconstructs, restricted to one side of the change.
String _joinTokens(List<DiffToken>? tokens, {required bool added}) =>
    (tokens ?? const <DiffToken>[])
        .where((t) => added ? !t.removed : !t.added)
        .map((t) => t.value)
        .join();

void main() {
  group('calculateUnifiedDiff — stats', () {
    test('identical text reports no changes and one context hunk', () {
      const text = 'alpha\nbeta\ngamma';
      final result = calculateUnifiedDiff(text, text);

      expect(result.stats.additions, 0);
      expect(result.stats.deletions, 0);
      expect(result.stats.totalChanges, 0);
      expect(result.hunks, hasLength(1));
      expect(
        _lines(result).map((l) => l.type),
        everyElement(DiffLineType.normal),
      );
      expect(_lines(result).map((l) => l.content), ['alpha', 'beta', 'gamma']);
    });

    test('appended lines count as additions only', () {
      final result = calculateUnifiedDiff('a\nb', 'a\nb\nc\nd');

      expect(result.stats.additions, 2);
      expect(result.stats.deletions, 0);
      expect(_ofType(result, DiffLineType.add).map((l) => l.content), [
        'c',
        'd',
      ]);
    });

    test('removed lines count as deletions only', () {
      final result = calculateUnifiedDiff('a\nb\nc\nd', 'a\nb');

      expect(result.stats.deletions, 2);
      expect(result.stats.additions, 0);
      expect(_ofType(result, DiffLineType.remove).map((l) => l.content), [
        'c',
        'd',
      ]);
    });

    test('a replaced line is one addition and one deletion', () {
      final result = calculateUnifiedDiff(
        'one\ntwo\nthree',
        'one\nTWO CHANGED\nthree',
      );

      expect(result.stats.additions, 1);
      expect(result.stats.deletions, 1);
      expect(result.stats.totalChanges, 2);
    });

    test('editing one line of a near-identical list changes one line', () {
      // Numbered/indented lines (list items, imports, JSON rows) are all
      // similar to their neighbours. A single edit must not cascade into
      // "everything below this changed".
      final oldText = List.generate(20, (i) => 'l$i').join('\n');
      final newText = List.generate(
        20,
        (i) => i == 10 ? 'l10 edited' : 'l$i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText);

      expect(result.stats.additions, 1);
      expect(result.stats.deletions, 1);
      expect(_ofType(result, DiffLineType.add).single.content, 'l10 edited');
      expect(_ofType(result, DiffLineType.remove).single.content, 'l10');
    });

    test('getDiffStats agrees with the full diff', () {
      const oldText = 'a\nb\nc';
      const newText = 'a\nB\nc\nd';
      final stats = getDiffStats(oldText, newText);

      expect(stats, calculateUnifiedDiff(oldText, newText).stats);
    });
  });

  group('calculateUnifiedDiff — line numbering', () {
    test('context lines carry both numbers, changes carry only theirs', () {
      final result = calculateUnifiedDiff('a\nb\nc', 'a\nB\nc');

      for (final line in _lines(result)) {
        switch (line.type) {
          case DiffLineType.normal:
            expect(line.oldLineNumber, isNotNull);
            expect(line.newLineNumber, isNotNull);
          case DiffLineType.add:
            expect(line.oldLineNumber, isNull);
            expect(line.newLineNumber, isNotNull);
          case DiffLineType.remove:
            expect(line.oldLineNumber, isNotNull);
            expect(line.newLineNumber, isNull);
        }
      }
    });

    test('old and new line numbers never repeat or go backwards', () {
      final oldText = List.generate(40, (i) => 'line $i').join('\n');
      final newText = List.generate(
        40,
        (i) => i == 5 || i == 30 ? 'line $i changed' : 'line $i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText);
      final olds = _lines(
        result,
      ).map((l) => l.oldLineNumber).whereType<int>().toList();
      final news = _lines(
        result,
      ).map((l) => l.newLineNumber).whereType<int>().toList();

      for (var i = 1; i < olds.length; i++) {
        expect(olds[i], greaterThan(olds[i - 1]));
      }
      for (var i = 1; i < news.length; i++) {
        expect(news[i], greaterThan(news[i - 1]));
      }
    });

    test('hunk headers match the lines they contain', () {
      final oldText = List.generate(30, (i) => 'l$i').join('\n');
      final newText = List.generate(
        30,
        (i) => i == 4 ? 'l4 edited' : 'l$i',
      ).join('\n');

      for (final hunk in calculateUnifiedDiff(oldText, newText).hunks) {
        expect(
          hunk.oldLines,
          hunk.lines.where((l) => l.oldLineNumber != null).length,
        );
        expect(
          hunk.newLines,
          hunk.lines.where((l) => l.newLineNumber != null).length,
        );
        expect(hunk.oldStart, greaterThanOrEqualTo(1));
        expect(hunk.newStart, greaterThanOrEqualTo(1));
      }
    });
  });

  group('calculateUnifiedDiff — hunks and context', () {
    test('distant changes split into separate hunks', () {
      final oldText = List.generate(60, (i) => 'l$i').join('\n');
      final newText = List.generate(
        60,
        (i) => i == 2 || i == 50 ? 'l$i edited' : 'l$i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText, contextLines: 2);

      expect(result.hunks.length, 2);
      // Unchanged middle lines are not carried into either hunk.
      expect(_lines(result).length, lessThan(30));
    });

    test('adjacent changes stay in a single hunk', () {
      final oldText = List.generate(20, (i) => 'l$i').join('\n');
      final newText = List.generate(
        20,
        (i) => i == 8 || i == 9 ? 'l$i edited' : 'l$i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText, contextLines: 3);

      expect(result.hunks, hasLength(1));
    });

    test('contextLines: 0 emits only the changed lines', () {
      final oldText = List.generate(20, (i) => 'l$i').join('\n');
      final newText = List.generate(
        20,
        (i) => i == 10 ? 'l10 edited' : 'l$i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText, contextLines: 0);

      expect(
        _ofType(result, DiffLineType.normal),
        isEmpty,
        reason: 'no context requested',
      );
      expect(_lines(result), hasLength(2));
    });

    test('a wide context window never duplicates a line', () {
      final oldText = List.generate(12, (i) => 'l$i').join('\n');
      final newText = List.generate(
        12,
        (i) => i == 3 || i == 5 || i == 11 ? 'l$i edited' : 'l$i',
      ).join('\n');

      final result = calculateUnifiedDiff(oldText, newText, contextLines: 6);
      final contents = _lines(
        result,
      ).map((l) => '${l.type}:${l.content}').toList();

      expect(contents, orderedEquals(contents.toSet().toList()));
    });
  });

  group('calculateUnifiedDiff — inline tokens', () {
    test('tokens reconstruct both sides of a modified line', () {
      final result = calculateUnifiedDiff(
        'final value = compute(a);',
        'final value = compute(b);',
      );

      final removed = _ofType(result, DiffLineType.remove).single;
      final added = _ofType(result, DiffLineType.add).single;

      expect(removed.tokens, isNotNull);
      expect(added.tokens, isNotNull);
      expect(_joinTokens(removed.tokens, added: false), removed.content);
      expect(_joinTokens(added.tokens, added: true), added.content);
    });

    test('indentation survives tokenization', () {
      final result = calculateUnifiedDiff(
        '        return oldValue;',
        '        return newValue;',
      );

      final added = _ofType(result, DiffLineType.add).single;
      expect(_joinTokens(added.tokens, added: true), startsWith('        '));
      expect(_joinTokens(added.tokens, added: true), added.content);
    });

    test('an unpaired addition carries no tokens', () {
      final result = calculateUnifiedDiff('a', 'a\nzzzzzzzzz');
      final added = _ofType(result, DiffLineType.add).single;

      expect(added.tokens, isNull);
    });
  });

  group('calculateUnifiedDiff — edge inputs', () {
    test('empty old text turns every new line into an addition', () {
      final result = calculateUnifiedDiff('', 'a\nb');

      expect(
        _ofType(result, DiffLineType.add).map((l) => l.content),
        containsAll(<String>['a', 'b']),
      );
      expect(result.stats.additions, greaterThanOrEqualTo(2));
    });

    test('empty new text removes every old line', () {
      final result = calculateUnifiedDiff('a\nb', '');

      expect(
        _ofType(result, DiffLineType.remove).map((l) => l.content),
        containsAll(<String>['a', 'b']),
      );
      expect(result.stats.deletions, greaterThanOrEqualTo(2));
    });

    test('two empty texts produce no changes', () {
      final result = calculateUnifiedDiff('', '');

      expect(result.stats.totalChanges, 0);
    });

    test('a dropped trailing newline is a single-line change', () {
      final result = calculateUnifiedDiff('a\n', 'a');

      expect(result.stats.deletions, 1);
      expect(result.stats.additions, 0);
    });

    test('unicode content diffs without throwing', () {
      final result = calculateUnifiedDiff(
        'emoji 🎉 line\nsecond ünïcode line',
        'emoji 🎉 line\nsecond ünïcode edit',
      );

      expect(result.stats.additions, 1);
      expect(result.stats.deletions, 1);
      expect(
        _ofType(result, DiffLineType.normal).map((l) => l.content),
        contains('emoji 🎉 line'),
      );
    });

    test(
      'a very long single line diffs in bounded time',
      () {
        // Minified JS/JSON arrives as one enormous line. The similarity
        // scan must not turn that into a multi-minute UI-isolate freeze.
        final longOld = 'x' * 4000;
        final longNew = '${'x' * 3999}y';

        final stopwatch = Stopwatch()..start();
        final result = calculateUnifiedDiff(longOld, longNew);
        stopwatch.stop();

        expect(result.stats.additions, 1);
        expect(result.stats.deletions, 1);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test('a whitespace-only change is still reported', () {
      final result = calculateUnifiedDiff('a\n  indented', 'a\n    indented');

      expect(result.stats.totalChanges, greaterThan(0));
    });
  });
}
