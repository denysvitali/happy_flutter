import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Counts decrypts; the wire "ciphertext" is the plaintext summary text.
class _CountingSessionEncryption implements SessionEncryption {
  int metadataDecrypts = 0;
  int agentStateDecrypts = 0;

  /// Observed by each decrypt: whether an unrelated zero-delay timer queued
  /// by the first decrypt had already fired.
  bool armTimerOnFirstDecrypt = false;
  bool timerFired = false;
  final List<bool> timerFiredAtDecrypt = [];

  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    metadataDecrypts++;
    timerFiredAtDecrypt.add(timerFired);
    if (armTimerOnFirstDecrypt && timerFiredAtDecrypt.length == 1) {
      Timer(Duration.zero, () => timerFired = true);
    }
    return {
      'host': 'h',
      'path': '/p/$encrypted',
      'todos': [
        {'content': 'todo $encrypted', 'status': 'pending', 'id': 't1'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async {
    agentStateDecrypts++;
    return {'controlledByUser': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this.sessionEncryption);

  SessionEncryption sessionEncryption;

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _wire(String id, {String cipher = 'v1', int v = 1}) => {
  'id': id,
  'seq': 1,
  'createdAt': 1700000000000,
  'updatedAt': 1700000000000,
  'active': false,
  'activeAt': 1700000000000,
  'metadata': cipher,
  'metadataVersion': v,
  'agentState': 'agent-$id',
  'agentStateVersion': 1,
};

void main() {
  late Sync sync;
  late _CountingSessionEncryption sessionEncryption;
  late List<Map<String, dynamic>> catalog;

  setUp(() async {
    sync = createTestSync();
    resetTestSync(sync);
    sessionEncryption = _CountingSessionEncryption();
    sync
      ..testIsInitialized = true
      ..testForceFullFetchNext = false
      ..encryption = _FakeEncryption(sessionEncryption);
    await ApiClient().initialize(serverUrl: 'http://localhost');
    catalog = [];
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'sessions': catalog, 'hasNext': false},
          ),
        ),
      ),
    );
  });

  tearDown(() {
    ApiClient().dispose();
    sync.testIsInitialized = false;
    resetTestSync(sync);
  });

  Future<void> fullFetch() async {
    // Every read is a full reconciliation, like a forced/daily/cold read.
    sync.testForceFullFetchNext = true;
    ApiClient().clearCache('/v2/sessions');
    await sync.fetchSessions();
  }

  // Larger than every EncryptionCache cap: a sequential scan of this many
  // rows evicted each entry before reuse, so every full read re-decrypted
  // the whole catalog on the UI isolate (production: 1,258 sessions).
  final catalogSize = EncryptionCache.maxMetadata + 300;

  test(
    'unchanged full catalog above the cache cap decrypts nothing on reread',
    () async {
      catalog = [for (var i = 0; i < catalogSize; i++) _wire('s$i')];

      await fullFetch();
      expect(sessionEncryption.metadataDecrypts, catalogSize);
      expect(sessionEncryption.agentStateDecrypts, catalogSize);
      final first = Map.of(sync.sessions);

      final stopwatch = Stopwatch()..start();
      await fullFetch();
      stopwatch.stop();

      expect(sessionEncryption.metadataDecrypts, catalogSize);
      expect(sessionEncryption.agentStateDecrypts, catalogSize);
      expect(sync.sessions.length, catalogSize);
      // Unchanged rows keep their instance, so identity-keyed consumers
      // (cache persistence, session UI diffing) see no change.
      for (final entry in first.entries) {
        expect(identical(sync.sessions[entry.key], entry.value), isTrue);
      }
      expect(sync.sessions['s7']?.metadata?.path, '/p/v1');
      expect(sync.sessions['s7']?.todos?.single.content, 'todo v1');
      expect(sync.sessions['s7']?.agentState?.controlledByUser, isTrue);
      // ignore: avoid_print
      print(
        'reread of $catalogSize unchanged sessions: '
        '${stopwatch.elapsedMilliseconds}ms',
      );
    },
  );

  test('changed ciphertext or version re-decrypts only that row', () async {
    catalog = [for (var i = 0; i < 20; i++) _wire('s$i')];
    await fullFetch();
    final before = sessionEncryption.metadataDecrypts;
    final untouched = sync.sessions['s1'];

    catalog = [
      for (var i = 0; i < 20; i++)
        i == 3
            ? _wire('s3', cipher: 'v2', v: 2)
            : i == 4
            // Same version, different ciphertext (e.g. a re-encryption).
            ? _wire('s4', cipher: 'v1-reencrypted')
            : _wire('s$i'),
    ];
    await fullFetch();

    expect(sessionEncryption.metadataDecrypts - before, 2);
    expect(sync.sessions['s3']?.metadata?.path, '/p/v2');
    expect(sync.sessions['s3']?.metadataVersion, 2);
    expect(sync.sessions['s4']?.metadata?.path, '/p/v1-reencrypted');
    expect(identical(sync.sessions['s1'], untouched), isTrue);
  });

  test('a replaced session decryptor never reuses the old decode', () async {
    catalog = [_wire('s1')];
    await fullFetch();
    final replacement = _CountingSessionEncryption();
    (sync.encryption as _FakeEncryption).sessionEncryption = replacement;

    await fullFetch();

    expect(replacement.metadataDecrypts, 1);
    expect(replacement.agentStateDecrypts, 1);
  });

  test('a failed metadata decrypt is retried on the next read', () async {
    final failing = _FailingOnceSessionEncryption();
    (sync.encryption as _FakeEncryption).sessionEncryption = failing;
    catalog = [_wire('s1')];

    await fullFetch();
    expect(sync.sessions['s1']?.metadata, isNull);

    await fullFetch();
    expect(failing.metadataDecrypts, 2);
    expect(sync.sessions['s1']?.metadata?.host, 'h');
  });

  test(
    'a cold catalog decrypt yields to the event loop between slices',
    () async {
      catalog = [for (var i = 0; i < 200; i++) _wire('s$i')];
      sync.testForceFullFetchNext = true;
      ApiClient().clearCache('/v2/sessions');
      sessionEncryption.armTimerOnFirstDecrypt = true;
      await sync.fetchSessions();

      final observed = sessionEncryption.timerFiredAtDecrypt;
      expect(observed, hasLength(200));
      // Previously all 200 rows ran in one microtask chain, so a timer could
      // never fire mid-catalog (a frame could not render either).
      expect(observed.first, isFalse);
      expect(observed.last, isTrue);
    },
  );

  test('runtime reset clears the memo', () async {
    catalog = [_wire('s1')];
    await fullFetch();
    sync.testClearEncryptionKeyCaches();

    await fullFetch();

    expect(sessionEncryption.metadataDecrypts, 2);
  });
}

class _FailingOnceSessionEncryption implements SessionEncryption {
  int metadataDecrypts = 0;

  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    metadataDecrypts++;
    return metadataDecrypts == 1 ? null : {'host': 'h'};
  }

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
