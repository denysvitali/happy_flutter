import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

DiffLine _line({List<DiffToken>? tokens}) => DiffLine(
  type: DiffLineType.add,
  content: 'final x = 1;',
  newLineNumber: 4,
  tokens: tokens,
);

List<DiffToken> _tokens() => <DiffToken>[
  const DiffToken(value: 'final '),
  const DiffToken(value: 'x', added: true),
];

DiffHunk _hunk(List<DiffLine> lines) => DiffHunk(
  oldStart: 1,
  oldLines: 1,
  newStart: 1,
  newLines: lines.length,
  lines: lines,
);

void main() {
  group('DiffToken', () {
    test('equal values and flags compare equal and hash equal', () {
      const a = DiffToken(value: 'x', added: true);
      const b = DiffToken(value: 'x', added: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the added/removed flags are part of identity', () {
      const plain = DiffToken(value: 'x');

      expect(plain, isNot(const DiffToken(value: 'x', added: true)));
      expect(plain, isNot(const DiffToken(value: 'x', removed: true)));
      expect(plain, isNot(const DiffToken(value: 'y')));
    });
  });

  group('DiffLine', () {
    test('identical content and tokens compare equal', () {
      expect(_line(tokens: _tokens()), _line(tokens: _tokens()));
    });

    test('equal lines hash equal so they can key a set or map', () {
      final a = _line(tokens: _tokens());
      final b = _line(tokens: _tokens());

      expect(a.hashCode, b.hashCode);
      expect(<DiffLine>{a, b}, hasLength(1));
    });

    test('a missing token list is not the same as an empty one', () {
      expect(_line(), isNot(_line(tokens: const <DiffToken>[])));
      expect(_line(tokens: const <DiffToken>[]), isNot(_line()));
    });

    test('differing token values break equality', () {
      final other = <DiffToken>[
        const DiffToken(value: 'final '),
        const DiffToken(value: 'y', added: true),
      ];

      expect(_line(tokens: _tokens()), isNot(_line(tokens: other)));
    });

    test('line numbers and type are part of identity', () {
      const base = DiffLine(
        type: DiffLineType.remove,
        content: 'a',
        oldLineNumber: 2,
      );

      expect(base, isNot(const DiffLine(type: DiffLineType.add, content: 'a')));
      expect(
        base,
        isNot(
          const DiffLine(
            type: DiffLineType.remove,
            content: 'a',
            oldLineNumber: 3,
          ),
        ),
      );
    });
  });

  group('DiffHunk and DiffResult', () {
    test('hunks with equal lines compare and hash equal', () {
      final a = _hunk([_line(tokens: _tokens())]);
      final b = _hunk([_line(tokens: _tokens())]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different line count breaks hunk equality', () {
      expect(_hunk([_line()]), isNot(_hunk([_line(), _line()])));
    });

    test('results with equal hunks and stats compare and hash equal', () {
      final a = DiffResult(
        hunks: [
          _hunk([_line(tokens: _tokens())]),
        ],
        stats: const DiffStats(additions: 1, deletions: 0),
      );
      final b = DiffResult(
        hunks: [
          _hunk([_line(tokens: _tokens())]),
        ],
        stats: const DiffStats(additions: 1, deletions: 0),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different stats break result equality', () {
      final hunks = [
        _hunk([_line()]),
      ];

      expect(
        DiffResult(
          hunks: hunks,
          stats: const DiffStats(additions: 1, deletions: 0),
        ),
        isNot(
          DiffResult(
            hunks: hunks,
            stats: const DiffStats(additions: 0, deletions: 1),
          ),
        ),
      );
    });
  });

  group('DiffStats', () {
    test('totalChanges sums both sides', () {
      expect(const DiffStats(additions: 3, deletions: 4).totalChanges, 7);
      expect(const DiffStats(additions: 0, deletions: 0).totalChanges, 0);
    });

    test('equal stats compare and hash equal', () {
      const a = DiffStats(additions: 2, deletions: 5);
      const b = DiffStats(additions: 2, deletions: 5);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
