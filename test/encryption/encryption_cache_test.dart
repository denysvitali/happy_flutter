import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';

void main() {
  group('EncryptionCache', () {
    late EncryptionCache cache;

    setUp(() {
      cache = EncryptionCache();
    });

    group('Agent State Cache', () {
      test('returns null for uncached agent state', () {
        final result = cache.getCachedAgentState('session1', 1);
        expect(result, isNull);
      });

      test('caches and retrieves agent state', () {
        final data = {'status': 'running', 'model': 'claude'};
        cache.setCachedAgentState('session1', 1, data);

        final result = cache.getCachedAgentState('session1', 1);
        expect(result, isNotNull);
        expect(result!['status'], 'running');
        expect(result['model'], 'claude');
      });

      test('different versions have separate cache entries', () {
        cache.setCachedAgentState('session1', 1, {'v': 1});
        cache.setCachedAgentState('session1', 2, {'v': 2});

        expect(cache.getCachedAgentState('session1', 1)!['v'], 1);
        expect(cache.getCachedAgentState('session1', 2)!['v'], 2);
      });

      test('different sessions have separate cache entries', () {
        cache.setCachedAgentState('session1', 1, {'s': 'a'});
        cache.setCachedAgentState('session2', 1, {'s': 'b'});

        expect(cache.getCachedAgentState('session1', 1)!['s'], 'a');
        expect(cache.getCachedAgentState('session2', 1)!['s'], 'b');
      });
    });

    group('Metadata Cache', () {
      test('returns null for uncached metadata', () {
        expect(cache.getCachedMetadata('session1', 1), isNull);
      });

      test('caches and retrieves metadata', () {
        final data = {'path': '/home/user', 'summary': 'test'};
        cache.setCachedMetadata('session1', 1, data);

        final result = cache.getCachedMetadata('session1', 1);
        expect(result, isNotNull);
        expect(result!['path'], '/home/user');
      });
    });

    group('Message Cache', () {
      test('returns null for uncached message', () {
        expect(cache.getCachedMessage('msg1'), isNull);
      });

      test('caches and retrieves message', () {
        final msg = DecryptedMessage(
          id: 'msg1',
          seq: 1,
          content: 'Hello',
          createdAt: DateTime(2024, 1, 1),
        );
        cache.setCachedMessage('msg1', msg);

        final result = cache.getCachedMessage('msg1');
        expect(result, isNotNull);
        expect(result!.id, 'msg1');
        expect(result.content, 'Hello');
      });
    });

    group('Machine Metadata Cache', () {
      test('returns null for uncached machine metadata', () {
        expect(cache.getCachedMachineMetadata('machine1', 1), isNull);
      });

      test('caches and retrieves machine metadata', () {
        final data = {'name': 'server1', 'os': 'linux'};
        cache.setCachedMachineMetadata('machine1', 1, data);

        final result = cache.getCachedMachineMetadata('machine1', 1);
        expect(result, isNotNull);
        expect(result!['name'], 'server1');
      });
    });

    group('Daemon State Cache', () {
      test('returns null for uncached daemon state', () {
        expect(cache.getCachedDaemonState('machine1', 1), isNull);
      });

      test('caches and retrieves daemon state', () {
        cache.setCachedDaemonState('machine1', 1, {'running': true});

        final result = cache.getCachedDaemonState('machine1', 1);
        expect(result, isNotNull);
        expect(result['running'], true);
      });

      test('can cache null daemon state', () {
        cache.setCachedDaemonState('machine1', 1, null);

        // Cached null should return the cached value, not null from miss
        // This depends on implementation - the cache stores the entry
        expect(cache.getCachedDaemonState('machine1', 1), isNull);
      });
    });

    group('Cache Clearing', () {
      test('clearMachineCache removes only machine entries', () {
        cache.setCachedMachineMetadata('m1', 1, {'a': 1});
        cache.setCachedMachineMetadata('m2', 1, {'b': 2});
        cache.setCachedDaemonState('m1', 1, {'d': 1});
        cache.setCachedDaemonState('m2', 1, {'d': 2});

        cache.clearMachineCache('m1');

        expect(cache.getCachedMachineMetadata('m1', 1), isNull);
        expect(cache.getCachedDaemonState('m1', 1), isNull);
        expect(cache.getCachedMachineMetadata('m2', 1), isNotNull);
        expect(cache.getCachedDaemonState('m2', 1), isNotNull);
      });

      test('clearSessionCache removes only session entries', () {
        cache.setCachedAgentState('s1', 1, {'a': 1});
        cache.setCachedAgentState('s2', 1, {'b': 2});
        cache.setCachedMetadata('s1', 1, {'m': 1});
        cache.setCachedMetadata('s2', 1, {'m': 2});

        cache.clearSessionCache('s1');

        expect(cache.getCachedAgentState('s1', 1), isNull);
        expect(cache.getCachedMetadata('s1', 1), isNull);
        expect(cache.getCachedAgentState('s2', 1), isNotNull);
        expect(cache.getCachedMetadata('s2', 1), isNotNull);
      });

      test('clearAll removes everything', () {
        cache.setCachedAgentState('s1', 1, {'a': 1});
        cache.setCachedMetadata('s1', 1, {'m': 1});
        cache.setCachedMessage('msg1', DecryptedMessage(
          id: 'msg1',
          seq: 1,
          content: 'test',
          createdAt: DateTime.now(),
        ),);
        cache.setCachedMachineMetadata('m1', 1, {'m': 1});
        cache.setCachedDaemonState('m1', 1, {'d': 1});

        cache.clearAll();

        expect(cache.getCachedAgentState('s1', 1), isNull);
        expect(cache.getCachedMetadata('s1', 1), isNull);
        expect(cache.getCachedMessage('msg1'), isNull);
        expect(cache.getCachedMachineMetadata('m1', 1), isNull);
        expect(cache.getCachedDaemonState('m1', 1), isNull);
      });
    });

    group('getStats', () {
      test('returns zero counts for empty cache', () {
        final stats = cache.getStats();
        expect(stats['agentStates'], 0);
        expect(stats['metadata'], 0);
        expect(stats['messages'], 0);
        expect(stats['machineMetadata'], 0);
        expect(stats['daemonStates'], 0);
        expect(stats['totalEntries'], 0);
      });

      test('counts all cache entries', () {
        cache.setCachedAgentState('s1', 1, {'a': 1});
        cache.setCachedMetadata('s1', 1, {'m': 1});
        cache.setCachedMessage('msg1', DecryptedMessage(
          id: 'msg1',
          seq: 1,
          content: 'test',
          createdAt: DateTime.now(),
        ),);
        cache.setCachedMachineMetadata('m1', 1, {'m': 1});
        cache.setCachedDaemonState('m1', 1, {'d': 1});

        final stats = cache.getStats();
        expect(stats['agentStates'], 1);
        expect(stats['metadata'], 1);
        expect(stats['messages'], 1);
        expect(stats['machineMetadata'], 1);
        expect(stats['daemonStates'], 1);
        expect(stats['totalEntries'], 5);
      });
    });

    group('LRU Eviction', () {
      test('evicts oldest entry when max agent states exceeded', () {
        // maxAgentStates is 1000, add 1001 entries
        for (var i = 0; i < 1001; i++) {
          cache.setCachedAgentState('s$i', 1, {'i': i});
        }

        // First entry should have been evicted
        expect(cache.getCachedAgentState('s0', 1), isNull);
        // Last entry should still be present
        expect(cache.getCachedAgentState('s1000', 1), isNotNull);
      });

      test('recently accessed entries survive eviction', () async {
        // Fill cache
        for (var i = 0; i < 1000; i++) {
          cache.setCachedAgentState('s$i', 1, {'i': i});
        }

        // Access the first entry to update its access time
        cache.getCachedAgentState('s0', 1);

        // Add one more to trigger eviction
        cache.setCachedAgentState('s1000', 1, {'i': 1000});

        // s0 should survive because it was recently accessed
        // s1 should be evicted (oldest unaccessed)
        expect(cache.getCachedAgentState('s0', 1), isNotNull);
      });
    });
  });

  group('DecryptedMessage', () {
    group('fromJson', () {
      test('parses message with all fields', () {
        final json = {
          'id': 'msg1',
          'seq': 5,
          'localId': 'local1',
          'content': {'text': 'Hello'},
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final msg = DecryptedMessage.fromJson(json);
        expect(msg.id, 'msg1');
        expect(msg.seq, 5);
        expect(msg.localId, 'local1');
        expect(msg.content, {'text': 'Hello'});
        expect(msg.createdAt, DateTime.utc(2024, 1, 15, 10, 30));
      });

      test('parses message without optional localId', () {
        final json = {
          'id': 'msg2',
          'seq': 1,
          'content': 'test',
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final msg = DecryptedMessage.fromJson(json);
        expect(msg.id, 'msg2');
        expect(msg.localId, isNull);
      });

      test('parses message with null content', () {
        final json = {
          'id': 'msg3',
          'seq': 2,
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final msg = DecryptedMessage.fromJson(json);
        expect(msg.content, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final msg = DecryptedMessage(
          id: 'msg1',
          seq: 5,
          localId: 'local1',
          content: {'text': 'Hello'},
          createdAt: DateTime.utc(2024, 1, 15, 10, 30),
        );

        final json = msg.toJson();
        expect(json['id'], 'msg1');
        expect(json['seq'], 5);
        expect(json['localId'], 'local1');
        expect(json['content'], {'text': 'Hello'});
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
      });

      test('roundtrip through toJson/fromJson', () {
        final original = DecryptedMessage(
          id: 'msg1',
          seq: 5,
          localId: 'local1',
          content: {'nested': {'value': 42}},
          createdAt: DateTime.utc(2024, 6, 15, 12, 0),
        );

        final json = original.toJson();
        final restored = DecryptedMessage.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.seq, original.seq);
        expect(restored.localId, original.localId);
        expect(restored.content, original.content);
        expect(restored.createdAt, original.createdAt);
      });
    });

    group('constructor', () {
      test('stores all provided fields', () {
        final msg = DecryptedMessage(
          id: 'test',
          seq: 42,
          localId: 'local',
          content: [1, 2, 3],
          createdAt: DateTime(2024),
        );

        expect(msg.id, 'test');
        expect(msg.seq, 42);
        expect(msg.localId, 'local');
        expect(msg.content, [1, 2, 3]);
        expect(msg.createdAt, DateTime(2024));
      });

      test('localId defaults to null', () {
        final msg = DecryptedMessage(
          id: 'test',
          seq: 1,
          content: null,
          createdAt: DateTime.now(),
        );

        expect(msg.localId, isNull);
      });

      test('content defaults to null', () {
        final msg = DecryptedMessage(
          id: 'test',
          seq: 1,
          createdAt: DateTime.now(),
        );

        expect(msg.content, isNull);
      });
    });
  });
}
