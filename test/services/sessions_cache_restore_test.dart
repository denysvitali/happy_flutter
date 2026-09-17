import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:happy_flutter/core/api/api_client.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/models/auth.dart';

import '../helpers/test_helpers.dart';

/// Regression: one undecryptable cached data key must not wipe the whole
/// restored session list.
///
/// The per-session decrypt ran inside a `Future.wait`, so a single throwing
/// entry rejected the whole future and fell into the catch-all at the end of
/// `_restoreSessionsCache`, which clears `_sessions`, the key maps, the delta
/// cursor AND the on-disk cache — turning one bad row into a full cold start.
void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _RestoreFakeEncryption(failingKey: 'bad-key');
  });

  tearDown(() {
    sync.testIsInitialized = false;
    sync.testSessions.clear();
  });

  for (final createFirst in [true, false]) {
    test(
      'initialization is single-flight and fenced (create=$createFirst)',
      () async {
        sync.testIsInitialized = false;
        const credentials = AuthCredentials(token: 'test-token', secret: 'key');
        final firstEncryption = _RestoreFakeEncryption(failingKey: 'bad-key');
        final ignoredEncryption = _RestoreFakeEncryption(failingKey: 'bad-key');
        final first = createFirst
            ? sync.create(credentials, firstEncryption)
            : sync.restore(credentials, firstEncryption);
        final second = createFirst
            ? sync.restore(credentials, ignoredEncryption)
            : sync.create(credentials, ignoredEncryption);
        expect(identical(first, second), isTrue);
        expect(identical(sync.encryption, firstEncryption), isTrue);
        await sync.shutdown();
        await Future.wait([first, second]);
        expect(sync.isInitialized, isFalse);
        expect(sync.isReady, isFalse);
      },
    );
  }

  test('a single undecryptable data key does not wipe the restore', () async {
    await sync.testRestoreSessionsCacheFrom({
      'sessions': [_rawSession('s-good'), _rawSession('s-bad')],
      'encryptedDataKeys': {'s-good': 'good-key', 's-bad': 'bad-key'},
      'lastFetchedAt': 1700000000000,
    });

    expect(
      sync.sessions.keys.toSet(),
      {'s-good', 's-bad'},
      reason:
          'the good session must survive a neighbour with a corrupt data key',
    );
  });

  for (final empty in [true, false]) {
    test('archive override survives full catalog (empty=$empty)', () async {
      await ApiClient().initialize(serverUrl: 'http://localhost');
      addTearDown(() => ApiClient().dispose());
      sync.testIsInitialized = true;
      sync.testLastSessionsFetchedAt = null;
      sync.markSessionArchived('hidden');
      addTearDown(() => sync.markSessionUnarchived('hidden'));
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'sessions': empty ? [] : [_rawSession('other')],
                'hasNext': false,
              },
            ),
          ),
        ),
      );
      await sync.fetchSessions();
      expect(sync.isSessionOptimisticallyArchived('hidden'), isTrue);
      sync.markSessionUnarchived('hidden');
      expect(sync.isSessionOptimisticallyArchived('hidden'), isFalse);
    });
  }

  test('stale key decrypt cannot restore the old delta cursor', () async {
    final gate = Completer<void>();
    sync.encryption = _RestoreFakeEncryption(
      failingKey: 'bad-key',
      decryptGate: gate.future,
    );
    final restoring = sync.testRestoreSessionsCacheFrom({
      'sessions': [_rawSession('old')],
      'encryptedDataKeys': {'old': 'key'},
      'lastFetchedAt': 123,
    });
    await sync.shutdown();
    sync.testLastSessionsFetchedAt = 456;
    gate.complete();
    await restoring;
    expect(sync.testLastSessionsFetchedAt, 456);
    expect(sync.sessions, isEmpty);
  });

  test('deferred cached sessions restore their encryption context', () async {
    final sessions = <Map<String, dynamic>>[
      for (var i = 0; i < 6; i++)
        _rawSession('s-$i')..['updatedAt'] = 1700000000000 + i,
    ];
    final encryptedDataKeys = <String, String>{
      for (var i = 0; i < 6; i++) 's-$i': 'key-$i',
    };

    final gate = Completer<void>();
    sync.testIsInitialized = false;
    sync.encryption = _RestoreFakeEncryption(
      failingKey: 'bad-key',
      decryptGate: gate.future,
    );
    final restored = sync.onDomainChanged.firstWhere(
      (_) =>
          sync.sessions.containsKey('s-0') &&
          sync.encryption.getSessionEncryption('s-0') != null,
    );
    final restoring = sync.testRestoreSessionsCacheFrom({
      'sessions': sessions,
      'encryptedDataKeys': encryptedDataKeys,
      'lastFetchedAt': 1700000000000,
    });
    gate.complete();
    await restoring;
    // The deferred tail must finish even though the runtime never reached
    // initialized while the recent-key decryption was still in flight —
    // exactly the cold-start ordering that used to abandon the tail.
    await restored.timeout(const Duration(seconds: 3));

    expect(sync.sessions, contains('s-0'));
    expect(
      sync.encryption.getSessionEncryption('s-0'),
      isNotNull,
      reason:
          'sessions beyond the five-row startup window must retain their '
          'cached DEK instead of waiting for a socket payload to force a '
          'network recovery',
    );
  });
}

Map<String, dynamic> _rawSession(String id) => <String, dynamic>{
  'id': id,
  'seq': 1,
  'createdAt': 1700000000000,
  'updatedAt': 1700000000000,
  'active': true,
  'activeAt': 1700000000000,
  'metadataVersion': 1,
  'agentStateVersion': 1,
  'thinking': false,
  'presence': 'offline',
  'lastSeq': 0,
};

class _RestoreFakeEncryption implements Encryption {
  _RestoreFakeEncryption({required this.failingKey, this.decryptGate});

  final String failingKey;

  @override
  String get anonId => 'test-anon';

  /// When set, every key decryption pauses until the test completes the
  /// gate, making the async window inside restore deterministic.
  final Future<void>? decryptGate;
  final Map<String, SessionEncryption> _sessionEncryptions = {};
  final EncryptionCache _cache = EncryptionCache();

  @override
  Future<Uint8List?> decryptEncryptionKey(String encrypted) async {
    final gate = decryptGate;
    if (gate != null) {
      await gate;
    }
    if (encrypted == failingKey) {
      throw StateError('corrupt cached data key');
    }
    return Uint8List(32);
  }

  @override
  Future<dynamic> openEncryption(Uint8List? dataEncryptionKey) async =>
      const _NoopEncryptor();

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessionEncryptions[sessionId];

  @override
  void setSessionEncryption(String sessionId, SessionEncryption encryption) {
    _sessionEncryptions[sessionId] = encryption;
  }

  @override
  void removeSessionEncryption(String sessionId) {
    _sessionEncryptions.remove(sessionId);
  }

  @override
  EncryptionCache get cache => _cache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopEncryptor implements Encryptor {
  const _NoopEncryptor();

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async => const [];

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async => const [];
}
