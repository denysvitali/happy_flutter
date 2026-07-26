import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

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
    sync.testSessions.clear();
  });

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
  _RestoreFakeEncryption({required this.failingKey});

  final String failingKey;

  @override
  Future<Uint8List?> decryptEncryptionKey(String encrypted) async {
    if (encrypted == failingKey) {
      throw StateError('corrupt cached data key');
    }
    return Uint8List(32);
  }

  @override
  Future<dynamic> openEncryption(Uint8List? dataEncryptionKey) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
