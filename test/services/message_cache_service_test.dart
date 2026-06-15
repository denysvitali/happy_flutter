import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_cache_service.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

/// In-memory MMKVStorage fake.  Only overrides the session-message
/// surface that [MessageCacheService] actually touches; everything
/// else inherits from the real MMKVStorage and stays unused.
class _InMemoryMMKVStorage extends MMKVStorage {
  _InMemoryMMKVStorage() : super.testConstructor();

  final Map<String, List<Map<String, dynamic>>> _sessions = {};

  /// Counts every read so tests can assert the second `getMessages`
  /// call did not have to re-scrub.
  int readCount = 0;

  /// Counts every write so tests can assert that no-op scrubs do not
  /// rewrite the cache.
  int writeCount = 0;

  @override
  List<Map<String, dynamic>> getSessionMessages(String sessionId) {
    readCount++;
    final stored = _sessions[sessionId];
    if (stored == null) return [];
    // Return a defensive copy so the service can mutate freely.
    return [for (final m in stored) Map<String, dynamic>.from(m)];
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(
    String sessionId,
  ) async {
    return getSessionMessages(sessionId);
  }

  @override
  bool saveSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    writeCount++;
    _sessions[sessionId] = [
      for (final m in messages) Map<String, dynamic>.from(m),
    ];
    // Web returns bool, native returns void.  Returning bool is a
    // valid override against both because void is a permissible
    // return for bool-returning methods (return value discarded).
    return true;
  }

  @override
  void clearSessionMessages(String sessionId) {
    _sessions.remove(sessionId);
  }

  @override
  List<String> getCachedSessionIds() => _sessions.keys.toList();

  /// Direct test-only inspection: what is actually persisted for a
  /// session, without going through MessageCacheService.
  List<Map<String, dynamic>> rawStored(String sessionId) => [
    for (final m in _sessions[sessionId] ?? const <Map<String, dynamic>>[])
      Map<String, dynamic>.from(m),
  ];

  /// Direct test-only seed: simulates legacy MMKV state without
  /// touching MessageCacheService.
  void rawSeed(String sessionId, List<Map<String, dynamic>> messages) {
    _sessions[sessionId] = [
      for (final m in messages) Map<String, dynamic>.from(m),
    ];
  }
}

Map<String, dynamic> _orphanRecoveryTask({
  required String id,
  required List<Map<String, dynamic>> children,
  int seq = 2,
}) {
  return <String, dynamic>{
    'id': id,
    'kind': 'task',
    'role': 'agent',
    '_orphanRecovery': true,
    'children': children,
    'seq': seq,
  };
}

void main() {
  group('MessageCacheService', () {
    test('trimForTesting keeps the most recent cache window', () {
      final messages = List<Map<String, dynamic>>.generate(
        250,
        (index) => {'id': 'message-$index', 'seq': index + 1},
      );

      final trimmed = MessageCacheService.trimForTesting(messages);

      expect(trimmed, hasLength(200));
      expect(trimmed.first['id'], 'message-50');
      expect(trimmed.last['id'], 'message-249');
    });

    test('trimForTesting preserves small caches unchanged', () {
      final messages = List<Map<String, dynamic>>.generate(
        12,
        (index) => {'id': 'message-$index', 'seq': index + 1},
      );

      final trimmed = MessageCacheService.trimForTesting(messages);

      expect(identical(trimmed, messages), isTrue);
      expect(trimmed, hasLength(12));
    });

    test('getMessagesAsync uses the async storage read path', () async {
      final storage = _InMemoryMMKVStorage()
        ..rawSeed('session-async', [
          {'id': 'message-1', 'seq': 1},
        ]);
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);

      final messages = await MessageCacheService().getMessagesAsync(
        'session-async',
      );

      expect(messages, hasLength(1));
      expect(messages.single['id'], 'message-1');
      expect(storage.readCount, 1);
    });

    test('saveMessages rewrites when older cached content changes', () {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      final messages = List.generate(
        10,
        (i) => <String, dynamic>{
          'id': 'msg-$i',
          'seq': i,
          'content': 'content-$i',
        },
      );

      MessageCacheService().saveMessages('session-1', messages);
      final changed = [
        for (final message in messages) Map<String, dynamic>.from(message),
      ];
      changed[1]['content'] = 'edited content';
      MessageCacheService().saveMessages('session-1', changed);

      expect(storage.writeCount, 2);
      expect(storage.rawStored('session-1')[1]['content'], 'edited content');
    });
  });

  group('MessageCacheService.stripOrphanSynthetics', () {
    test('replaces synthetic Task with re-flagged isSidechain children', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'real-1',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        _orphanRecoveryTask(
          id: 'synthetic-1',
          children: [
            <String, dynamic>{
              'id': 'c1',
              'isSidechain': true,
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
            },
            <String, dynamic>{
              'id': 'c2',
              'isSidechain': true,
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
        <String, dynamic>{
          'id': 'real-2',
          'kind': 'text',
          'role': 'agent',
          'seq': 4,
        },
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped.map((m) => m['id']).toList(), [
        'real-1',
        'c1',
        'c2',
        'real-2',
      ]);
      expect(stripped[1]['isSidechain'], isTrue);
      expect(stripped[2]['isSidechain'], isTrue);
      expect(stripped.where((m) => m['_orphanRecovery'] == true), isEmpty);
    });

    test('re-flags children whose isSidechain was missing or false', () {
      final input = <Map<String, dynamic>>[
        _orphanRecoveryTask(
          id: 'synthetic',
          children: [
            <String, dynamic>{
              'id': 'c-missing',
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
              // intentionally no isSidechain
            },
            <String, dynamic>{
              'id': 'c-false',
              'isSidechain': false,
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped, hasLength(2));
      expect(stripped[0]['id'], 'c-missing');
      expect(stripped[0]['isSidechain'], isTrue);
      expect(stripped[1]['id'], 'c-false');
      expect(stripped[1]['isSidechain'], isTrue);
    });

    test('returns the same list when no synthetics are present', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ];
      final stripped = MessageCacheService.stripOrphanSynthetics(input);
      expect(
        identical(stripped, input),
        isTrue,
        reason: 'no-op path must avoid allocation',
      );
    });

    test('drops synthetic with no children list', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'real', 'kind': 'text', 'seq': 1},
        <String, dynamic>{
          'id': 'synthetic',
          'kind': 'task',
          '_orphanRecovery': true,
          // no 'children' key at all
          'seq': 2,
        },
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped, hasLength(1));
      expect(stripped[0]['id'], 'real');
    });
  });

  group('MessageCacheService.getMessages — orphan-synthetic scrub', () {
    late _InMemoryMMKVStorage storage;

    setUp(() {
      storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
    });

    tearDown(() {
      MessageCacheService().debugResetStorage();
    });

    test('returns synthetic-free output when MMKV had a persisted synthetic '
        'Task with children', () {
      storage.rawSeed('session-1', [
        <String, dynamic>{
          'id': 'real-1',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        _orphanRecoveryTask(
          id: 'synthetic-1',
          children: [
            <String, dynamic>{
              'id': 'c1',
              'isSidechain': true,
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
            },
            <String, dynamic>{
              'id': 'c2',
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
      ]);

      final messages = MessageCacheService().getMessages('session-1');

      expect(messages.map((m) => m['id']).toList(), ['real-1', 'c1', 'c2']);
      expect(messages.where((m) => m['_orphanRecovery'] == true), isEmpty);
      // Both children are re-emitted as top-level isSidechain entries.
      expect(messages[1]['isSidechain'], isTrue);
      expect(messages[2]['isSidechain'], isTrue);
    });

    test(
      'rewrites the cleaned cache back to MMKV so the next read is free',
      () {
        storage.rawSeed('session-2', [
          <String, dynamic>{
            'id': 'real',
            'kind': 'text',
            'role': 'user',
            'seq': 1,
          },
          _orphanRecoveryTask(
            id: 'synthetic',
            children: [
              <String, dynamic>{
                'id': 'child',
                'uuid': 'u',
                'parentUuid': 'X',
                'seq': 2,
              },
            ],
          ),
        ]);

        // First read scrubs and persists.
        MessageCacheService().getMessages('session-2');

        // Inspect MMKV directly: the persisted form must be clean.
        final stored = storage.rawStored('session-2');
        expect(stored.map((m) => m['id']).toList(), ['real', 'child']);
        expect(stored.where((m) => m['_orphanRecovery'] == true), isEmpty);
        expect(stored.last['isSidechain'], isTrue);
      },
    );

    test('is a no-op for caches with no synthetics (no extra write)', () {
      storage.rawSeed('session-3', [
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ]);

      final writesBefore = storage.writeCount;
      final messages = MessageCacheService().getMessages('session-3');

      expect(messages.map((m) => m['id']).toList(), ['a', 'b']);
      expect(
        storage.writeCount,
        writesBefore,
        reason: 'a synthetic-free cache must not trigger a rewrite',
      );
    });

    test('leaves cache untouched when only a partial scrub would be needed '
        '(synthetic without children list still gets cleaned + persisted)', () {
      storage.rawSeed('session-4', [
        <String, dynamic>{
          'id': 'real',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        <String, dynamic>{
          'id': 'synthetic',
          'kind': 'task',
          '_orphanRecovery': true,
          'seq': 2,
        },
      ]);

      final messages = MessageCacheService().getMessages('session-4');
      expect(messages.map((m) => m['id']).toList(), ['real']);

      final stored = storage.rawStored('session-4');
      expect(stored.map((m) => m['id']).toList(), ['real']);
      expect(stored.any((m) => m['_orphanRecovery'] == true), isFalse);
    });
  });

  group('MessageCacheService.stripOrphanSynthetics', () {
    test('replaces synthetic Task with re-flagged isSidechain children', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'real-1',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        _orphanRecoveryTask(
          id: 'synthetic-1',
          children: [
            <String, dynamic>{
              'id': 'c1',
              'isSidechain': true,
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
            },
            <String, dynamic>{
              'id': 'c2',
              'isSidechain': true,
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
        <String, dynamic>{
          'id': 'real-2',
          'kind': 'text',
          'role': 'agent',
          'seq': 4,
        },
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped.map((m) => m['id']).toList(), [
        'real-1',
        'c1',
        'c2',
        'real-2',
      ]);
      expect(stripped[1]['isSidechain'], isTrue);
      expect(stripped[2]['isSidechain'], isTrue);
      expect(stripped.where((m) => m['_orphanRecovery'] == true), isEmpty);
    });

    test('re-flags children whose isSidechain was missing or false', () {
      final input = <Map<String, dynamic>>[
        _orphanRecoveryTask(
          id: 'synthetic',
          children: [
            <String, dynamic>{
              'id': 'c-missing',
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
              // intentionally no isSidechain
            },
            <String, dynamic>{
              'id': 'c-false',
              'isSidechain': false,
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped, hasLength(2));
      expect(stripped[0]['id'], 'c-missing');
      expect(stripped[0]['isSidechain'], isTrue);
      expect(stripped[1]['id'], 'c-false');
      expect(stripped[1]['isSidechain'], isTrue);
    });

    test('returns the same list when no synthetics are present', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ];
      final stripped = MessageCacheService.stripOrphanSynthetics(input);
      expect(
        identical(stripped, input),
        isTrue,
        reason: 'no-op path must avoid allocation',
      );
    });

    test('drops synthetic with no children list', () {
      final input = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'real', 'kind': 'text', 'seq': 1},
        <String, dynamic>{
          'id': 'synthetic',
          'kind': 'task',
          '_orphanRecovery': true,
          // no 'children' key at all
          'seq': 2,
        },
      ];

      final stripped = MessageCacheService.stripOrphanSynthetics(input);

      expect(stripped, hasLength(1));
      expect(stripped[0]['id'], 'real');
    });
  });

  group('MessageCacheService.getMessages — orphan-synthetic scrub', () {
    late _InMemoryMMKVStorage storage;

    setUp(() {
      storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
    });

    tearDown(() {
      MessageCacheService().debugResetStorage();
    });

    test('returns synthetic-free output when MMKV had a persisted synthetic '
        'Task with children', () {
      storage.rawSeed('session-1', [
        <String, dynamic>{
          'id': 'real-1',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        _orphanRecoveryTask(
          id: 'synthetic-1',
          children: [
            <String, dynamic>{
              'id': 'c1',
              'isSidechain': true,
              'uuid': 'u1',
              'parentUuid': 'X',
              'seq': 2,
            },
            <String, dynamic>{
              'id': 'c2',
              'uuid': 'u2',
              'parentUuid': 'u1',
              'seq': 3,
            },
          ],
        ),
      ]);

      final messages = MessageCacheService().getMessages('session-1');

      expect(messages.map((m) => m['id']).toList(), ['real-1', 'c1', 'c2']);
      expect(messages.where((m) => m['_orphanRecovery'] == true), isEmpty);
      // Both children are re-emitted as top-level isSidechain entries.
      expect(messages[1]['isSidechain'], isTrue);
      expect(messages[2]['isSidechain'], isTrue);
    });

    test(
      'rewrites the cleaned cache back to MMKV so the next read is free',
      () {
        storage.rawSeed('session-2', [
          <String, dynamic>{
            'id': 'real',
            'kind': 'text',
            'role': 'user',
            'seq': 1,
          },
          _orphanRecoveryTask(
            id: 'synthetic',
            children: [
              <String, dynamic>{
                'id': 'child',
                'uuid': 'u',
                'parentUuid': 'X',
                'seq': 2,
              },
            ],
          ),
        ]);

        // First read scrubs and persists.
        MessageCacheService().getMessages('session-2');

        // Inspect MMKV directly: the persisted form must be clean.
        final stored = storage.rawStored('session-2');
        expect(stored.map((m) => m['id']).toList(), ['real', 'child']);
        expect(stored.where((m) => m['_orphanRecovery'] == true), isEmpty);
        expect(stored.last['isSidechain'], isTrue);
      },
    );

    test('is a no-op for caches with no synthetics (no extra write)', () {
      storage.rawSeed('session-3', [
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ]);

      final writesBefore = storage.writeCount;
      final messages = MessageCacheService().getMessages('session-3');

      expect(messages.map((m) => m['id']).toList(), ['a', 'b']);
      expect(
        storage.writeCount,
        writesBefore,
        reason: 'a synthetic-free cache must not trigger a rewrite',
      );
    });

    test('leaves cache untouched when only a partial scrub would be needed '
        '(synthetic without children list still gets cleaned + persisted)', () {
      storage.rawSeed('session-4', [
        <String, dynamic>{
          'id': 'real',
          'kind': 'text',
          'role': 'user',
          'seq': 1,
        },
        <String, dynamic>{
          'id': 'synthetic',
          'kind': 'task',
          '_orphanRecovery': true,
          'seq': 2,
        },
      ]);

      final messages = MessageCacheService().getMessages('session-4');
      expect(messages.map((m) => m['id']).toList(), ['real']);

      final stored = storage.rawStored('session-4');
      expect(stored.map((m) => m['id']).toList(), ['real']);
      expect(stored.any((m) => m['_orphanRecovery'] == true), isFalse);
    });
  });
}
