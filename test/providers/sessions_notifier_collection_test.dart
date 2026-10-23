import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/sessions_notifier.dart';
import 'package:happy_flutter/core/services/pinned_sessions_storage.dart';
import 'package:happy_flutter/core/services/session_folders_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_helpers.dart';

/// Collection-level invariants for [SessionsNotifier]: identity
/// preservation across `loadFromSync`, optimistic archive bookkeeping, and
/// optimistic delete/batch-delete rollback restoring the exact prior map.
void main() {
  late ProviderContainer container;

  Session buildSession(
    String id, {
    int updatedAt = 1000,
    bool archived = false,
    String? name,
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      active: !archived,
      activeAt: updatedAt,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      archived: archived,
      presence: archived ? 'offline' : 'online',
      metadata: Metadata(
        host: 'host',
        path: '/repo',
        machineId: 'm1',
        name: name,
      ),
    );
  }

  setUp(() {
    container = ProviderContainer();
    createTestSync();
    sync
      ..testSessions.clear()
      ..testClearSpawnGuardState()
      ..testResetDataChangeCounters();
  });

  tearDown(() {
    sync
      ..testSessions.clear()
      ..testClearSpawnGuardState()
      ..testIsInitialized = false;
    container.dispose();
  });

  group('loadFromSync identity', () {
    test(
      'catalog changes support independent readers and bounded fallback',
      () {
        final start = sync.sessionCatalogRevision;
        final a = buildSession('a');
        sync.testSessions['a'] = a;
        final afterA = sync.sessionCatalogRevision;
        sync.testSessions['a'] = a;
        expect(sync.sessionCatalogRevision, afterA);
        sync.testSessions['b'] = buildSession('b');
        sync.testSessions.remove('a');
        expect(sync.sessionCatalogChangesSince(start), {'a', 'b'});
        expect(sync.sessionCatalogChangesSince(afterA), {'a', 'b'});
        expect(
          sync.sessionCatalogChangesSince(sync.sessionCatalogRevision),
          isEmpty,
        );
        final boundary = sync.sessionCatalogRevision;
        for (var i = 0; i < 1024; i++) {
          sync.testSessions['new-$i'] = buildSession('new-$i');
        }
        expect(sync.sessionCatalogChangesSince(boundary)!.length, 1024);
        sync.testSessions['overflow'] = buildSession('overflow');
        expect(sync.sessionCatalogChangesSince(boundary), isNull);
        expect(sync.sessionCatalogChangesSince(afterA), isNull);
        final beforeClear = sync.sessionCatalogRevision;
        sync.testSessions.clear();
        expect(sync.sessionCatalogChangesSince(beforeClear), isNull);
      },
    );

    test(
      'incremental snapshots match full fingerprints across compactions',
      () {
        var snapshot = SessionCollectionSnapshot({
          for (var i = 0; i < 500; i++) 's$i': buildSession('s$i'),
        });
        final original = snapshot;
        final expected = Map<String, Session>.from(snapshot);
        for (var i = 0; i < 80; i++) {
          final id = 's${i % 23}';
          final replacement = buildSession(id, updatedAt: 2000 + i);
          expected[id] = replacement;
          snapshot = SessionCollectionSnapshot.patch(snapshot, {
            id: replacement,
          });
          final full = SessionCollectionSnapshot(expected);
          expect(snapshot.collectionRevision, full.collectionRevision);
          expect(snapshot.missionControlRevision, full.missionControlRevision);
          expect(snapshot, expected);
        }
        snapshot = SessionCollectionSnapshot.patch(snapshot, {'s0': null});
        expect(snapshot.containsKey('s0'), isFalse);
        expect(snapshot.length, 499);
        expect(original['s0']!.updatedAt, 1000);
        expect(original.length, 500);
        expect(
          () => snapshot['bad'] = buildSession('bad'),
          throwsUnsupportedError,
        );
      },
    );

    test('unchanged entries keep identity when one session changes', () {
      sync.testIsInitialized = true;
      final a = buildSession('a');
      final b = buildSession('b');
      final c = buildSession('c');
      sync.testSessions.addAll({'a': a, 'b': b, 'c': c});
      sync.testNotifyDataChanged();

      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.loadFromSync();
      final first = container.read(sessionsNotifierProvider);
      expect(identical(first['a'], a), isTrue);

      final b2 = buildSession('b', updatedAt: 2000);
      sync.testSessions['b'] = b2;
      sync.testNotifyDataChanged();
      notifier.loadFromSync();

      final second = container.read(sessionsNotifierProvider);
      expect(identical(second, first), isFalse);
      expect(identical(second['a'], a), isTrue);
      expect(identical(second['c'], c), isTrue);
      expect(identical(second['b'], b2), isTrue);
      expect(second.keys.toSet(), {'a', 'b', 'c'});
    });

    test('catalog deltas retain local pin and folder overrides', () async {
      sync.testIsInitialized = true;
      final pins = PinnedSessionsStorage.instance;
      final folders = SessionFoldersStorage.instance;
      addTearDown(() {
        pins.clearAll();
        folders.clearAll();
      });
      await pins.pinSession('a');
      await folders.setFolder('a', 'Local');
      sync.testSessions['a'] = buildSession('a');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.loadFromSync();
      for (var i = 0; i < 40; i++) {
        sync.testSessions['a'] = buildSession('a', updatedAt: 2000 + i);
        sync.testNotifyDomains({SyncDomain.sessions});
        notifier.loadFromSync();
        final row = container.read(sessionsNotifierProvider)['a']!;
        expect(row.pinned, isTrue);
        expect(row.folder, 'Local');
        expect(row.updatedAt, 2000 + i);
      }
      sync.testSessions
        ..clear()
        ..['replacement'] = buildSession('replacement');
      sync.testNotifyDomains({SyncDomain.sessions});
      notifier.loadFromSync();
      expect(container.read(sessionsNotifierProvider).keys, ['replacement']);
    });

    test('a counter bump with identical entries keeps the same state', () {
      sync.testIsInitialized = true;
      sync.testSessions.addAll({
        'a': buildSession('a'),
        'b': buildSession('b'),
      });
      sync.testNotifyDataChanged();

      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.loadFromSync();
      final first = container.read(sessionsNotifierProvider);

      sync.testNotifyDataChanged();
      notifier.loadFromSync();
      expect(
        identical(container.read(sessionsNotifierProvider), first),
        isTrue,
      );
    });

    test('an unchanged sessions counter is a no-op even with new data', () {
      sync.testIsInitialized = true;
      sync.testSessions['a'] = buildSession('a');
      sync.testNotifyDataChanged();

      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.loadFromSync();
      final first = container.read(sessionsNotifierProvider);

      // No notify: the domain counter is unchanged, so the notifier must
      // not observe the new map.
      sync.testSessions['b'] = buildSession('b');
      notifier.loadFromSync();
      expect(
        identical(container.read(sessionsNotifierProvider), first),
        isTrue,
      );
      expect(first.keys, ['a']);
    });

    test('a removed session disappears without disturbing the rest', () {
      sync.testIsInitialized = true;
      final a = buildSession('a');
      sync.testSessions.addAll({'a': a, 'gone': buildSession('gone')});
      sync.testNotifyDataChanged();

      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.loadFromSync();
      sync.testSessions.remove('gone');
      sync.testNotifyDataChanged();
      notifier.loadFromSync();

      final state = container.read(sessionsNotifierProvider);
      expect(state.keys, ['a']);
      expect(identical(state['a'], a), isTrue);
    });
  });

  group('SessionCollectionSnapshot', () {
    test('equal content yields an equal revision; archive flips it', () {
      final base = {'a': buildSession('a'), 'b': buildSession('b')};
      final same = {'b': buildSession('b'), 'a': buildSession('a')};
      final archived = {
        'a': buildSession('a', archived: true),
        'b': buildSession('b'),
      };
      expect(
        SessionCollectionSnapshot(base).collectionRevision,
        SessionCollectionSnapshot(same).collectionRevision,
      );
      expect(
        SessionCollectionSnapshot(base).collectionRevision,
        isNot(SessionCollectionSnapshot(archived).collectionRevision),
      );
    });

    test('wrapping a snapshot returns the same instance', () {
      final snapshot = SessionCollectionSnapshot({'a': buildSession('a')});
      expect(identical(SessionCollectionSnapshot(snapshot), snapshot), isTrue);
      final published = container.read(sessionsNotifierProvider);
      expect(published, isA<SessionCollectionSnapshot>());
    });
  });

  group('archive bookkeeping', () {
    test('markSessionArchived flags the id optimistically in sync', () async {
      sync.testIsInitialized = true;
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a'), buildSession('b')]);

      await notifier.markSessionArchived('a', true);
      expect(sync.getOptimisticallyArchivedIds(), {'a'});
      // The collection itself is untouched until the server confirms.
      expect(container.read(sessionsNotifierProvider).keys, ['a', 'b']);

      sync.markSessionUnarchived('a');
      expect(sync.getOptimisticallyArchivedIds(), isEmpty);
    });

    test('unarchive through the notifier is a no-op', () async {
      sync.testIsInitialized = true;
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a')]);
      sync.markSessionArchived('a');

      await notifier.markSessionArchived('a', false);
      expect(sync.getOptimisticallyArchivedIds(), {'a'});
    });

    test('archive is ignored while sync is uninitialized', () async {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a')]);
      await notifier.markSessionArchived('a', true);
      expect(sync.getOptimisticallyArchivedIds(), isEmpty);
    });
  });

  group('optimistic delete', () {
    late Set<String> okIds;
    late Set<String> throwIds;
    final deleteRequests = <String>[];

    setUp(() async {
      okIds = {};
      throwIds = {};
      deleteRequests.clear();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            const prefix = '/v1/sessions/';
            if (options.method == 'DELETE' && options.path.startsWith(prefix)) {
              final id = options.path.substring(prefix.length);
              deleteRequests.add(id);
              if (throwIds.contains(id)) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
                return;
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: okIds.contains(id) ? 200 : 500,
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );
    });

    tearDown(() {
      ApiClient().dispose();
    });

    test('success removes the row and reports true', () async {
      okIds.add('a');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a'), buildSession('b')]);

      final ok = await notifier.optimisticDelete('a');
      expect(ok, isTrue);
      expect(container.read(sessionsNotifierProvider).keys, ['b']);
      expect(deleteRequests, ['a']);
    });

    test('server rejection restores the exact prior snapshot', () async {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a'), buildSession('b')]);
      final before = container.read(sessionsNotifierProvider);

      final ok = await notifier.optimisticDelete('a');
      expect(ok, isFalse);
      expect(
        identical(container.read(sessionsNotifierProvider), before),
        isTrue,
      );
    });

    test('transport failure restores the exact prior snapshot', () async {
      throwIds.add('a');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a'), buildSession('b')]);
      final before = container.read(sessionsNotifierProvider);

      final ok = await notifier.optimisticDelete('a');
      expect(ok, isFalse);
      expect(
        identical(container.read(sessionsNotifierProvider), before),
        isTrue,
      );
    });

    test('the row is gone while the request is in flight', () async {
      okIds.add('a');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a'), buildSession('b')]);

      final pending = notifier.optimisticDelete('a');
      // Yield once so the pre-request cleanup step (no-op for non-k8s
      // sessions) has resolved and the optimistic publish has run.
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(sessionsNotifierProvider).containsKey('a'),
        isFalse,
      );
      await pending;
    });

    test('batch delete restores only the failed ids', () async {
      okIds.addAll({'a', 'c'});
      throwIds.add('d');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      final b = buildSession('b', name: 'keep-b');
      final d = buildSession('d', name: 'keep-d');
      notifier.setSessions([
        buildSession('a'),
        b,
        buildSession('c'),
        d,
        buildSession('e'),
      ]);

      final failed = await notifier.optimisticBatchDelete(['a', 'b', 'c', 'd']);
      expect(failed, 2);
      final state = container.read(sessionsNotifierProvider);
      expect(state.keys.toSet(), {'b', 'd', 'e'});
      expect(identical(state['b'], b), isTrue);
      expect(identical(state['d'], d), isTrue);
      expect(deleteRequests.toSet(), {'a', 'b', 'c', 'd'});
    });

    test('batch delete with every id failing restores the whole map', () async {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      final sessions = [for (var i = 0; i < 6; i++) buildSession('s$i')];
      notifier.setSessions(sessions);
      final before = container.read(sessionsNotifierProvider);

      final failed = await notifier.optimisticBatchDelete(
        sessions.map((s) => s.id).toList(),
      );
      expect(failed, 6);
      final after = container.read(sessionsNotifierProvider);
      expect(after.keys.toSet(), before.keys.toSet());
      for (final session in sessions) {
        expect(identical(after[session.id], session), isTrue);
      }
    });

    test('batch delete of an empty list is a no-op', () async {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a')]);
      final before = container.read(sessionsNotifierProvider);
      expect(await notifier.optimisticBatchDelete(const []), 0);
      expect(
        identical(container.read(sessionsNotifierProvider), before),
        isTrue,
      );
      expect(deleteRequests, isEmpty);
    });

    test('deleting an unknown id does not disturb the collection', () async {
      okIds.add('ghost');
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a')]);
      final before = container.read(sessionsNotifierProvider);
      expect(await notifier.optimisticDelete('ghost'), isTrue);
      final after = container.read(sessionsNotifierProvider);
      expect(after.keys, ['a']);
      expect(identical(after['a'], before['a']), isTrue);
    });
  });
}
