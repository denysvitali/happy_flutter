import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/at_rest_encryption_service.dart';
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
  bool saveSessionMessagesEncoded(String sessionId, String encodedMessages) {
    final decoded = (jsonDecode(encodedMessages) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return saveSessionMessages(sessionId, decoded);
  }

  @override
  void clearSessionMessages(String sessionId) {
    _sessions.remove(sessionId);
  }

  @override
  List<String> getCachedSessionIds() => _sessions.keys.toList();

  /// Direct test-only inspection: what is actually persisted for a
  /// session, without going through MessageCacheService.
  List<Map<String, dynamic>> rawStored(String sessionId) {
    final stored = _sessions[sessionId] ?? const <Map<String, dynamic>>[];
    if (stored.length == 1 &&
        stored.single['_happyAtRestCiphertext'] is String) {
      final protection = AtRestEncryptionService.memoryOnly(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
      );
      final plaintext = protection.unprotectString(
        stored.single['_happyAtRestCiphertext']! as String,
        associatedData: 'message-cache:v1:$sessionId',
      );
      return (jsonDecode(plaintext!) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    return [for (final m in stored) Map<String, dynamic>.from(m)];
  }

  String? rawEncoded(String sessionId) {
    final stored = _sessions[sessionId];
    return stored == null ? null : jsonEncode(stored);
  }

  /// Direct test-only seed: simulates legacy MMKV state without
  /// touching MessageCacheService.
  void rawSeed(String sessionId, List<Map<String, dynamic>> messages) {
    _sessions[sessionId] = [
      for (final m in messages) Map<String, dynamic>.from(m),
    ];
  }
}

class _DelayedCacheReadStorage extends _InMemoryMMKVStorage {
  _DelayedCacheReadStorage({required this.encodedRead});

  final bool encodedRead;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> getSessionMessagesEncodedAsync(String sessionId) async {
    if (!encodedRead) return null;
    started.complete();
    await release.future;
    return rawEncoded(sessionId);
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(
    String sessionId,
  ) async {
    started.complete();
    await release.future;
    return getSessionMessages(sessionId);
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

    test('persisted cache is encrypted and restores canonical localId', () {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      final messages = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'local-p0',
          'localId': 'local-p0',
          'seq': 1,
          'content': 'private cache text',
        },
      ];

      MessageCacheService().saveMessages('protected-cache', messages);

      final raw = storage.rawEncoded('protected-cache')!;
      expect(raw, contains(AtRestEncryptionService.envelopePrefix));
      expect(raw, isNot(contains('private cache text')));
      expect(raw, isNot(contains('local-p0')));
      final restored = MessageCacheService().getMessages('protected-cache');
      expect(restored.single['localId'], 'local-p0');
      expect(restored.single['content'], 'private cache text');
    });

    test('async cache worker persists only an encrypted marker', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);

      await MessageCacheService().saveMessagesAsync('protected-async', [
        <String, dynamic>{
          'id': 'async-local',
          'localId': 'async-local',
          'seq': 1,
          'content': 'async private text',
        },
      ]);

      final raw = storage.rawEncoded('protected-async')!;
      expect(raw, contains(AtRestEncryptionService.envelopePrefix));
      expect(raw, isNot(contains('async-local')));
      expect(raw, isNot(contains('async private text')));
    });

    test('legacy plaintext cache is returned once and rewritten encrypted', () {
      final storage = _InMemoryMMKVStorage()
        ..rawSeed('legacy-cache', [
          <String, dynamic>{
            'id': 'legacy-local',
            'localId': 'legacy-local',
            'seq': 1,
            'content': 'legacy plaintext',
          },
        ]);
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);

      final restored = MessageCacheService().getMessages('legacy-cache');

      expect(restored.single['localId'], 'legacy-local');
      final migrated = storage.rawEncoded('legacy-cache')!;
      expect(migrated, contains(AtRestEncryptionService.envelopePrefix));
      expect(migrated, isNot(contains('legacy plaintext')));
    });
  });

  group('MessageCacheService — runtime-scoped reads', () {
    for (final encodedRead in [false, true]) {
      test(
        'stale ${encodedRead ? 'encoded' : 'fallback'} read cannot rewrite',
        () async {
          const sessionId = 'stale-read';
          final storage = _DelayedCacheReadStorage(encodedRead: encodedRead);
          final cache = MessageCacheService()..debugSetStorage = storage;
          cache.clearMessages(sessionId);
          storage.rawSeed(sessionId, [
            {'id': 'old', 'localId': 'old-local', 'content': 'private'},
          ]);
          addTearDown(cache.debugResetStorage);
          addTearDown(() => cache.clearMessages(sessionId));
          var current = true;
          final read = cache.getMessagesAsync(
            sessionId,
            isCurrent: () => current,
          );
          await storage.started.future;
          current = false;
          storage.release.complete();

          expect(await read, isEmpty);
          expect(storage.writeCount, 0);
          expect(storage.rawStored(sessionId).single['localId'], 'old-local');
        },
      );
    }

    test(
      'current scoped repairs commit without a native write await',
      () async {
        const sessionId = 'current-read-repair';
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        cache.clearMessages(sessionId);
        addTearDown(cache.debugResetStorage);
        addTearDown(() => cache.clearMessages(sessionId));
        var nativeWrites = 0;
        MessageCacheService.debugNativeWorkerWrite = (_, _) async {
          nativeWrites++;
          return true;
        };
        addTearDown(() => MessageCacheService.debugNativeWorkerWrite = null);
        final rows = <Map<String, dynamic>>[
          {'id': 'current', 'localId': 'current-local', 'content': 'private'},
        ];

        await cache.saveMessagesAsync(sessionId, rows, isCurrent: () => true);

        expect(nativeWrites, 0);
        expect(storage.writeCount, 1);
        expect(cache.getMessages(sessionId), rows);
      },
    );

    test('read-repair worker cannot commit after runtime reset', () async {
      const sessionId = 'stale-read-repair';
      final storage = _InMemoryMMKVStorage();
      final cache = MessageCacheService()..debugSetStorage = storage;
      cache.clearMessages(sessionId);
      storage.rawSeed(sessionId, [
        {'id': 'old', 'localId': 'old-local', 'content': 'private'},
      ]);
      addTearDown(cache.debugResetStorage);
      addTearDown(() => cache.clearMessages(sessionId));
      var current = true;
      MessageCacheService.debugWorkerInputSink = (_, _) => current = false;
      addTearDown(() => MessageCacheService.debugWorkerInputSink = null);

      await cache.saveMessagesAsync(
        sessionId,
        storage.rawStored(sessionId),
        isCurrent: () => current,
      );

      expect(storage.writeCount, 0);
      expect(storage.rawEncoded(sessionId), isNot(contains('happy-at-rest:')));
    });
  });

  group('MessageCacheService — complete persisted snapshots', () {
    final original = <String, dynamic>{
      'id': 'task-1',
      'seq': 1,
      'content': 'unchanged',
      'state': 'completed',
      'localId': 'local-1',
      'result': 'old result',
      'permission': {'status': 'pending'},
      'completedAt': 10,
      'children': [
        {'id': 'child-1', 'content': 'old child', 'result': 'old'},
      ],
    };
    final changes = <String, Map<String, dynamic>>{
      'appended child': {
        'children': [
          {'id': 'child-1', 'content': 'old child', 'result': 'old'},
          {'id': 'child-2', 'content': 'new child'},
        ],
      },
      'nested result': {
        'children': [
          {'id': 'child-1', 'content': 'old child', 'result': 'new'},
        ],
      },
      'completed result': {'result': 'new result'},
      'permission': {
        'permission': {'status': 'approved'},
      },
      'canonical localId': {'localId': 'canonical-1'},
      'completion time': {'completedAt': 20},
      'middle text': {'content': '${'x' * 200}new${'x' * 200}'},
      'middle list': {
        'content': [for (var i = 0; i < 20; i++) i == 10 ? 'new' : 'same'],
      },
      'late map entry': {
        'content': {
          for (var i = 0; i < 20; i++) '$i': i == 19 ? 'new' : 'same',
        },
      },
    };

    for (final asyncWrite in [false, true]) {
      for (final withRevision in [false, true]) {
        for (final change in changes.entries) {
          test(
            '${change.key}, async=$asyncWrite revision=$withRevision',
            () async {
              final storage = _InMemoryMMKVStorage();
              final cache = MessageCacheService()..debugSetStorage = storage;
              const sessionId = 'complete-snapshot';
              cache.clearMessages(sessionId);
              addTearDown(cache.debugResetStorage);
              addTearDown(() => cache.clearMessages(sessionId));
              final before = <String, dynamic>{...original};
              if (change.key == 'middle text') {
                before['content'] = '${'x' * 200}old${'x' * 200}';
              } else if (change.key == 'middle list') {
                before['content'] = List<String>.filled(20, 'same');
              } else if (change.key == 'late map entry') {
                before['content'] = {for (var i = 0; i < 20; i++) '$i': 'same'};
              }
              final after = <String, dynamic>{...before, ...change.value};
              Future<void> save(Map<String, dynamic> row, int revision) async {
                if (asyncWrite) {
                  await cache.saveMessagesAsync(sessionId, [
                    row,
                  ], revision: withRevision ? revision : null);
                } else {
                  cache.saveMessages(sessionId, [
                    row,
                  ], revision: withRevision ? revision : null);
                }
              }

              await save(before, 1);
              await save(after, 2);

              expect(storage.writeCount, 2);
              expect(cache.getMessages(sessionId), [after]);
              expect(await cache.getMessagesAsync(sessionId), [after]);
            },
          );
        }
      }
    }

    for (final asyncWrite in [false, true]) {
      test('nested changes still sanitize images, async=$asyncWrite', () async {
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        const sessionId = 'nested-sanitized-change';
        cache.clearMessages(sessionId);
        addTearDown(cache.debugResetStorage);
        addTearDown(() => cache.clearMessages(sessionId));
        final after = <String, dynamic>{
          ...original,
          'children': [
            {
              'id': 'child-1',
              'content': 'new child',
              'raw': {
                'content': [
                  {
                    'type': 'image',
                    'source': {'type': 'base64', 'data': 'private-image-bytes'},
                  },
                ],
              },
            },
          ],
        };
        cache.saveMessages(sessionId, [original]);
        if (asyncWrite) {
          await cache.saveMessagesAsync(sessionId, [after]);
        } else {
          cache.saveMessages(sessionId, [after]);
        }

        final restored = cache.getMessages(sessionId);
        final child =
            (restored.single['children'] as List<dynamic>).single
                as Map<String, dynamic>;
        expect(child['content'], 'new child');
        final raw = child['raw'] as Map<String, dynamic>;
        final image =
            (raw['content'] as List<dynamic>).single as Map<String, dynamic>;
        final source = image['source'] as Map<String, dynamic>;
        expect(source['data'], isEmpty);
        expect(source['omitted'], isTrue);
        expect(storage.writeCount, 2);
        final unchanged = storage.writeCount;
        await cache.saveMessagesAsync(sessionId, [after]);
        expect(storage.writeCount, unchanged);
        expect(jsonEncode(after), contains('private-image-bytes'));
      });
    }

    test('new revisions commit even when the sanitized bytes match', () async {
      final storage = _InMemoryMMKVStorage();
      final cache = MessageCacheService()..debugSetStorage = storage;
      const sessionId = 'revision-authority';
      cache.clearMessages(sessionId);
      addTearDown(cache.debugResetStorage);
      addTearDown(() => cache.clearMessages(sessionId));

      await cache.saveMessagesAsync(sessionId, [original], revision: 1);
      await cache.saveMessagesAsync(sessionId, [original], revision: 2);
      cache.saveMessages(sessionId, [original], revision: 3);
      expect(storage.writeCount, 3);
      await cache.saveMessagesAsync(sessionId, [original], revision: 3);
      expect(storage.writeCount, 3);
    });

    test(
      'repeated sends retain identities through retry and reordered echoes',
      () async {
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        const sessionId = 'snapshot-local-id-contract';
        cache.clearMessages(sessionId);
        addTearDown(cache.debugResetStorage);
        addTearDown(() => cache.clearMessages(sessionId));
        Map<String, dynamic> row(String id, String localId, String status) => {
          'id': id,
          'localId': localId,
          'content': 'continue',
          'sendStatus': status,
        };
        final first = row('optimistic-a', 'local-a', 'failed');
        final second = row('optimistic-b', 'local-b', 'sending');
        cache.saveMessages(sessionId, [first, second], revision: 1);
        final retry = row('optimistic-a', 'local-a', 'sending');
        await cache.saveMessagesAsync(sessionId, [retry, second], revision: 2);
        expect(cache.getMessages(sessionId).first['localId'], 'local-a');

        // Upstream merge has replaced each exact optimistic identity, with the
        // second echo delivered first. Persistence must preserve that snapshot.
        final echoedSecond = row('server-b', 'local-b', 'sent');
        await cache.saveMessagesAsync(sessionId, [
          retry,
          echoedSecond,
        ], revision: 3);
        final echoedFirst = row('server-a', 'local-a', 'sent');
        await cache.saveMessagesAsync(sessionId, [
          echoedFirst,
          echoedSecond,
        ], revision: 4);
        final restored = cache.getMessages(sessionId);
        expect(restored, [echoedFirst, echoedSecond]);
        expect(restored.map((m) => m['localId']).toSet(), {
          'local-a',
          'local-b',
        });
        expect(
          restored.where((m) => '${m['id']}'.startsWith('optimistic-')),
          isEmpty,
        );
      },
    );
  });

  group('MessageCacheService — async write queue', () {
    List<Map<String, dynamic>> window(String marker) => [
      <String, dynamic>{'id': 'm-1', 'seq': 1, 'content': marker},
    ];

    test(
      'completed saves release ciphertext without losing cached rows',
      () async {
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        addTearDown(cache.debugResetStorage);
        final ids = [for (var i = 0; i < 12; i++) 'marker-release-$i'];
        addTearDown(() => ids.forEach(cache.clearMessages));

        for (var i = 0; i < ids.length; i++) {
          final rows = <Map<String, dynamic>>[
            {
              'id': 'local-$i',
              'localId': 'local-$i',
              'seq': 1,
              'content': 'continue',
            },
          ];
          if (i.isEven) {
            cache.saveMessages(ids[i], rows);
          } else {
            await cache.saveMessagesAsync(ids[i], rows);
          }
          expect(cache.debugRetainedRepairMarkerBytes, 0);
          expect(cache.getMessages(ids[i]).single['localId'], 'local-$i');
        }
      },
    );

    test(
      'native worker race repairs the synchronous save then releases it',
      () async {
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        addTearDown(cache.debugResetStorage);
        addTearDown(() => cache.clearMessages('native-repair'));
        final entered = Completer<void>();
        final release = Completer<void>();
        MessageCacheService.debugNativeWorkerWrite = (sessionId, marker) async {
          entered.complete();
          await release.future;
          storage.saveSessionMessagesEncoded(sessionId, marker);
          return true;
        };
        addTearDown(() => MessageCacheService.debugNativeWorkerWrite = null);

        final pending = cache.saveMessagesAsync('native-repair', window('old'));
        await entered.future;
        cache.saveMessages('native-repair', [
          {'id': 'stable', 'localId': 'stable', 'seq': 2, 'content': 'new'},
        ]);
        expect(cache.debugRetainedRepairMarkerBytes, greaterThan(0));
        release.complete();
        await pending;

        expect(storage.rawStored('native-repair').single['localId'], 'stable');
        expect(storage.rawStored('native-repair').single['content'], 'new');
        expect(cache.debugRetainedRepairMarkerBytes, 0);
      },
    );

    test('native worker cannot resurrect a deleted cache', () async {
      final storage = _InMemoryMMKVStorage();
      final cache = MessageCacheService()..debugSetStorage = storage;
      addTearDown(cache.debugResetStorage);
      addTearDown(() => cache.clearMessages('native-delete'));
      final entered = Completer<void>();
      final release = Completer<void>();
      MessageCacheService.debugNativeWorkerWrite = (sessionId, marker) async {
        entered.complete();
        await release.future;
        storage.saveSessionMessagesEncoded(sessionId, marker);
        return true;
      };
      addTearDown(() => MessageCacheService.debugNativeWorkerWrite = null);

      final pending = cache.saveMessagesAsync('native-delete', window('old'));
      await entered.future;
      cache.clearMessages('native-delete');
      release.complete();
      await pending;

      expect(storage.rawStored('native-delete'), isEmpty);
      expect(cache.debugRetainedRepairMarkerBytes, 0);
    });

    test(
      'unchanged synchronous save fences a different native worker write',
      () async {
        final storage = _InMemoryMMKVStorage();
        final cache = MessageCacheService()..debugSetStorage = storage;
        addTearDown(cache.debugResetStorage);
        addTearDown(() => cache.clearMessages('native-unchanged'));
        cache.saveMessages('native-unchanged', window('committed'));
        final entered = Completer<void>();
        final release = Completer<void>();
        MessageCacheService.debugNativeWorkerWrite = (sessionId, marker) async {
          entered.complete();
          await release.future;
          storage.saveSessionMessagesEncoded(sessionId, marker);
          return true;
        };
        addTearDown(() => MessageCacheService.debugNativeWorkerWrite = null);

        final pending = cache.saveMessagesAsync(
          'native-unchanged',
          window('stale'),
        );
        await entered.future;
        cache.saveMessages('native-unchanged', window('committed'));
        release.complete();
        await pending;

        expect(
          storage.rawStored('native-unchanged').single['content'],
          'committed',
        );
        expect(cache.debugRetainedRepairMarkerBytes, 0);
      },
    );

    test('rapid async saves for one session collapse to a single write', () {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('queue-1'));

      // Three snapshots queued in the same event-loop turn: only the
      // last one is worth persisting, and only one encode isolate may
      // ever be spawned for them.
      final first = MessageCacheService().saveMessagesAsync(
        'queue-1',
        window('v1'),
      );
      final second = MessageCacheService().saveMessagesAsync(
        'queue-1',
        window('v2'),
      );
      final third = MessageCacheService().saveMessagesAsync(
        'queue-1',
        window('v3'),
      );

      return Future.wait<void>([first, second, third]).then((_) {
        expect(
          storage.writeCount,
          1,
          reason: 'superseded snapshots must not each reach MMKV',
        );
        expect(storage.rawStored('queue-1').single['content'], 'v3');
      });
    });

    test('an unchanged window after a committed save writes nothing', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('queue-2'));

      await MessageCacheService().saveMessagesAsync('queue-2', window('same'));
      expect(storage.writeCount, 1);

      await MessageCacheService().saveMessagesAsync('queue-2', window('same'));

      expect(
        storage.writeCount,
        1,
        reason: 'dirty tracking must skip a byte-identical cache window',
      );
    });

    test(
      'a committed revision skips all repeated worker preparation',
      () async {
        final storage = _InMemoryMMKVStorage();
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);
        addTearDown(
          () => MessageCacheService().clearMessages('queue-revision'),
        );
        var workerInputs = 0;
        MessageCacheService.debugWorkerInputSink = (_, _) => workerInputs++;
        addTearDown(() => MessageCacheService.debugWorkerInputSink = null);

        await MessageCacheService().saveMessagesAsync(
          'queue-revision',
          window('v1'),
          revision: 7,
        );
        await MessageCacheService().saveMessagesAsync(
          'queue-revision',
          window('v1'),
          revision: 7,
        );

        expect(storage.writeCount, 1);
        expect(
          workerInputs,
          1,
          reason: 'an unchanged revision must not cross the isolate boundary',
        );
      },
    );

    test(
      'worker trims and strips inline image bytes before persistence',
      () async {
        final storage = _InMemoryMMKVStorage();
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);
        addTearDown(() => MessageCacheService().clearMessages('queue-worker'));
        final workerInputCounts = <int>[];
        MessageCacheService.debugWorkerInputSink = (_, count) {
          workerInputCounts.add(count);
        };
        addTearDown(() => MessageCacheService.debugWorkerInputSink = null);
        final messages = List<Map<String, dynamic>>.generate(
          205,
          (index) => <String, dynamic>{
            'id': 'm-$index',
            'seq': index + 1,
            if (index == 204)
              'raw': <String, dynamic>{
                'content': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'image',
                    'source': <String, dynamic>{
                      'type': 'base64',
                      'media_type': 'image/png',
                      'data': 'large-inline-payload',
                    },
                  },
                ],
              },
          },
        );

        await MessageCacheService().saveMessagesAsync('queue-worker', messages);

        final stored = storage.rawStored('queue-worker');
        expect(stored, hasLength(200));
        expect(stored.first['id'], 'm-5');
        final raw = stored.last['raw'] as Map<String, dynamic>;
        final content = raw['content'] as List<dynamic>;
        final image = content.single as Map<String, dynamic>;
        final source = image['source'] as Map<String, dynamic>;
        expect(source['data'], isEmpty);
        expect(source['omitted'], isTrue);
        expect(
          workerInputCounts,
          <int>[200],
          reason: 'only the bounded cache window may cross to the worker',
        );
      },
    );

    test('worker strips inline image bytes from nested sidechains', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('queue-nested'));

      await MessageCacheService().saveMessagesAsync('queue-nested', [
        <String, dynamic>{
          'id': 'task-1',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'child-1',
              'raw': <String, dynamic>{
                'content': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'image',
                    'source': <String, dynamic>{
                      'type': 'base64',
                      'data': 'nested-large-payload',
                    },
                  },
                ],
              },
            },
          ],
        },
      ]);

      final stored = storage.rawStored('queue-nested');
      final children = stored.single['children'] as List<dynamic>;
      final child = children.single as Map<String, dynamic>;
      final raw = child['raw'] as Map<String, dynamic>;
      final content = raw['content'] as List<dynamic>;
      final image = content.single as Map<String, dynamic>;
      final source = image['source'] as Map<String, dynamic>;
      expect(source['data'], isEmpty);
      expect(source['omitted'], isTrue);
    });

    test('background flush writes the newest snapshot off the UI isolate '
        'exactly once', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('bg-flush'));
      final queued = MessageCacheService().saveMessagesAsync(
        'bg-flush',
        window('stale'),
        revision: 1,
      );

      final flush = MessageCacheService().flushPendingMessagesInBackground(
        <String, List<Map<String, dynamic>>>{'bg-flush': window('fresh')},
        latestRevisions: const <String, int>{'bg-flush': 2},
      );

      expect(
        storage.writeCount,
        0,
        reason: 'the flush must not encode or write synchronously',
      );
      await Future.wait(<Future<void>>[queued, flush]);
      expect(storage.rawStored('bg-flush').single['content'], 'fresh');
      expect(storage.writeCount, 1);
    });

    test('background flush includes debounced sessions and skips committed '
        'revisions', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('bg-timer'));
      final latest = <String, List<Map<String, dynamic>>>{
        'bg-timer': window('timer'),
        'bg-untouched': window('untouched'),
      };

      await MessageCacheService().flushPendingMessagesInBackground(
        latest,
        additionalSessionIds: const <String>['bg-timer'],
        latestRevisions: const <String, int>{'bg-timer': 7},
      );
      expect(storage.rawStored('bg-timer').single['content'], 'timer');
      expect(storage.rawStored('bg-untouched'), isEmpty);
      final writes = storage.writeCount;

      await MessageCacheService().flushPendingMessagesInBackground(
        latest,
        additionalSessionIds: const <String>['bg-timer'],
        latestRevisions: const <String, int>{'bg-timer': 7},
      );
      expect(
        storage.writeCount,
        writes,
        reason: 'a rapid second suspend must not rewrite a committed revision',
      );
    });

    test(
      'suspend flush persists service-owned queued work synchronously',
      () async {
        final storage = _InMemoryMMKVStorage();
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);
        addTearDown(() => MessageCacheService().clearMessages('queue-flush'));
        final messages = window('queued');
        final pending = MessageCacheService().saveMessagesAsync(
          'queue-flush',
          messages,
        );

        MessageCacheService().flushPendingMessages(
          <String, List<Map<String, dynamic>>>{'queue-flush': messages},
        );

        expect(storage.rawStored('queue-flush').single['content'], 'queued');
        await pending;
        expect(storage.rawStored('queue-flush').single['content'], 'queued');
        expect(
          storage.writeCount,
          1,
          reason: 'the fenced async worker must not repeat the suspend write',
        );
      },
    );

    test(
      'a cache read seeds dirty tracking so cold start does not rewrite',
      () async {
        final storage = _InMemoryMMKVStorage()
          ..rawSeed('queue-5', [
            <String, dynamic>{'id': 'm-1', 'seq': 1, 'content': 'restored'},
          ]);
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);
        addTearDown(() => MessageCacheService().clearMessages('queue-5'));

        final restored = MessageCacheService().getMessages('queue-5');
        final writesAfterRead = storage.writeCount;

        await MessageCacheService().saveMessagesAsync('queue-5', restored);

        expect(
          storage.writeCount,
          writesAfterRead,
          reason:
              'restoring N sessions on cold start must not immediately '
              'rewrite N identical cache windows',
        );
      },
    );

    test('clearMessages fences an in-flight async save', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);

      final pending = MessageCacheService().saveMessagesAsync(
        'queue-3',
        window('doomed'),
      );
      // Session deleted before the background encode finished — the
      // stale write must not resurrect the cache.
      MessageCacheService().clearMessages('queue-3');
      await pending;

      expect(storage.rawStored('queue-3'), isEmpty);
    });

    test('synchronous flush wins over an older in-flight async save', () async {
      final storage = _InMemoryMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);
      addTearDown(() => MessageCacheService().clearMessages('queue-4'));

      final pending = MessageCacheService().saveMessagesAsync(
        'queue-4',
        window('async'),
      );
      // Suspend flush: writes synchronously so the process can die
      // right after. The older async write must not clobber it.
      MessageCacheService().saveMessages('queue-4', window('flushed'));
      await pending;

      expect(storage.rawStored('queue-4').single['content'], 'flushed');
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

    test('synthetic-free legacy cache only gets the encryption rewrite', () {
      storage.rawSeed('session-3', [
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ]);

      final writesBefore = storage.writeCount;
      final messages = MessageCacheService().getMessages('session-3');

      expect(messages.map((m) => m['id']).toList(), ['a', 'b']);
      expect(
        storage.writeCount,
        writesBefore + 1,
        reason: 'legacy plaintext must migrate exactly once',
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

    test('synthetic-free legacy cache only gets the encryption rewrite', () {
      storage.rawSeed('session-3', [
        <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
        <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
      ]);

      final writesBefore = storage.writeCount;
      final messages = MessageCacheService().getMessages('session-3');

      expect(messages.map((m) => m['id']).toList(), ['a', 'b']);
      expect(
        storage.writeCount,
        writesBefore + 1,
        reason: 'legacy plaintext must migrate exactly once',
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
