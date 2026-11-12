import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_nesting.dart';

Session _s(
  String id, {
  String? parent,
  bool thinking = false,
  bool online = true,
  bool permission = false,
  int activeAt = 1,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: activeAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: online ? 'online' : 'offline',
    agentState: permission
        ? AgentState(
            requests: {
              'r1': const RequestInfo(
                tool: 'Bash',
                arguments: <String, dynamic>{},
              ),
            },
          )
        : null,
    metadata: Metadata(
      path: '/w',
      parentSessionId: parent,
      rootSessionId: parent == null ? null : 'root',
      nestingDepth: parent == null ? null : 1,
      spawnedBy: parent == null ? null : 'agent',
    ),
  );
}

Map<String, Session> _catalog(Iterable<Session> sessions) => {
  for (final s in sessions) s.id: s,
};

List<String> _ids(Iterable<Session> sessions) => [
  for (final s in sessions) s.id,
];

void main() {
  group('Metadata nesting fields', () {
    test('parses display-only spawn metadata', () {
      final m = Metadata.fromJson({
        'parentSessionId': 'p1',
        'rootSessionId': 'r1',
        'nestingDepth': 2,
        'spawnedBy': 'agent',
      });
      expect(m.parentSessionId, 'p1');
      expect(m.rootSessionId, 'r1');
      expect(m.nestingDepth, 2);
      expect(m.spawnedBy, 'agent');
      expect(m.isSubSession, isTrue);
    });

    test('tolerates absence and wrong types', () {
      expect(Metadata.fromJson(const {}).isSubSession, isFalse);
      final m = Metadata.fromJson({
        'parentSessionId': 42,
        'rootSessionId': '  ',
        'nestingDepth': 'deep',
        'spawnedBy': false,
      });
      expect(m.parentSessionId, isNull);
      expect(m.rootSessionId, isNull);
      expect(m.nestingDepth, isNull);
      expect(m.spawnedBy, isNull);
      expect(m.isSubSession, isFalse);
      expect(Metadata.fromJson({'nestingDepth': 1.0}).nestingDepth, 1);
    });
  });

  group('SessionNesting.build', () {
    test('keeps an unrelated list unchanged and identical', () {
      final list = [_s('a'), _s('b')];
      final nesting = SessionNesting.build(list);
      expect(identical(nesting.topLevel, list), isTrue);
      expect(nesting.hasNesting, isFalse);
    });

    test('nests a direct child under its visible parent exactly once', () {
      final list = [_s('child', parent: 'p'), _s('other'), _s('p')];
      final nesting = SessionNesting.build(list);
      expect(_ids(nesting.topLevel), ['other', 'p']);
      expect(_ids(nesting.childrenOf('p')), ['child']);
      expect(nesting.isNested('child'), isTrue);
      expect(nesting.isOrphan('child'), isFalse);
      final everyRow = [
        ...nesting.topLevel,
        for (final s in nesting.topLevel) ...nesting.descendantsOf(s.id),
      ];
      expect(_ids(everyRow)..sort(), ['child', 'other', 'p']);
    });

    test('orphan child whose parent is absent stays top-level', () {
      final list = [_s('child', parent: 'archived-parent'), _s('x')];
      final nesting = SessionNesting.build(list);
      expect(_ids(nesting.topLevel), ['child', 'x']);
      expect(nesting.isOrphan('child'), isTrue);
      expect(nesting.isNested('child'), isFalse);
      expect(nesting.hasNesting, isFalse);
    });

    test('multi-level: grandchildren nest under children', () {
      final list = [
        _s('root'),
        _s('c1', parent: 'root'),
        _s('g1', parent: 'c1'),
        _s('c2', parent: 'root'),
      ];
      final nesting = SessionNesting.build(list);
      expect(_ids(nesting.topLevel), ['root']);
      expect(_ids(nesting.childrenOf('root')), ['c1', 'c2']);
      expect(_ids(nesting.childrenOf('c1')), ['g1']);
      expect(_ids(nesting.descendantsOf('root')), ['c1', 'g1', 'c2']);
      expect(nesting.summaryOf('root').total, 3);
    });

    test('filtered-out middle generation lifts grandchild to root', () {
      final root = _s('root');
      final middle = _s('mid', parent: 'root');
      final grand = _s('g', parent: 'mid');
      // Search/filter removed `mid` from the shown list.
      final nesting = SessionNesting.build([
        root,
        grand,
      ], catalog: _catalog([root, middle, grand]));
      expect(_ids(nesting.topLevel), ['root']);
      expect(_ids(nesting.childrenOf('root')), ['g']);
    });

    test('filtered-out parent makes the child an orphan', () {
      final parent = _s('p');
      final child = _s('c', parent: 'p');
      final nesting = SessionNesting.build([
        child,
      ], catalog: _catalog([parent, child]));
      expect(_ids(nesting.topLevel), ['c']);
      expect(nesting.isOrphan('c'), isTrue);
    });

    test('a parent cycle never hides both sessions', () {
      final a = _s('a', parent: 'b');
      final b = _s('b', parent: 'a');
      final self = _s('self', parent: 'self');
      final nesting = SessionNesting.build([a, b, self]);
      // Every session renders somewhere: either top-level or reachable.
      final reachable = {
        for (final s in nesting.topLevel) ...[
          s.id,
          ..._ids(nesting.descendantsOf(s.id)),
        ],
      };
      expect(reachable, {'a', 'b', 'self'});
      expect(nesting.isOrphan('self'), isTrue);
      expect(_ids(nesting.topLevel), ['a', 'self']);
      expect(_ids(nesting.childrenOf('a')), ['b']);
    });

    test('summary counts working and attention descendants', () {
      final list = [
        _s('p'),
        _s('w', parent: 'p', thinking: true),
        _s('n', parent: 'p', permission: true, thinking: true),
        _s('off', parent: 'p', thinking: true, online: false),
      ];
      final summary = SessionNesting.build(list).summaryOf('p');
      expect(summary.total, 3);
      expect(summary.working, 1);
      expect(summary.needsAttention, 1);
    });

    test('shownIds follows expansion of the whole ancestor chain', () {
      final nesting = SessionNesting.build([
        _s('root'),
        _s('c', parent: 'root'),
        _s('g', parent: 'c'),
      ]);
      expect(nesting.shownIds(['root'], (_) => false), {'root'});
      expect(nesting.shownIds(['root'], (id) => id == 'root'), {'root', 'c'});
      expect(nesting.shownIds(['root'], (id) => id == 'c'), {'root'});
      expect(nesting.shownIds(['root'], (_) => true), {'root', 'c', 'g'});
    });

    test('merge keeps active and archived relations separate', () {
      final active = SessionNesting.build([_s('p'), _s('c', parent: 'p')]);
      final archived = SessionNesting.build([_s('old', parent: 'p')]);
      final merged = active.merge(archived);
      expect(_ids(merged.topLevel), ['p', 'old']);
      expect(_ids(merged.childrenOf('p')), ['c']);
      expect(merged.isOrphan('old'), isTrue);
      expect(merged.isNested('c'), isTrue);
    });
  });

  test('subSessionsOf lists every loaded child, newest first', () {
    final catalog = _catalog([
      _s('p'),
      _s('old', parent: 'p', activeAt: 1),
      _s('new', parent: 'p', activeAt: 9),
      _s('other', parent: 'q'),
    ]);
    expect(_ids(subSessionsOf(catalog, 'p')), ['new', 'old']);
  });
}
