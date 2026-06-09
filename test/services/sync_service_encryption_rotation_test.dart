import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

class _TrackingSessionKeys {
  _TrackingSessionKeys(this.key);

  final Uint8List key;
}

class _TrackingEncryptor implements Encryptor {
  _TrackingEncryptor(this.key);

  final Uint8List key;

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final bytes = utf8.encode(jsonEncode(item));
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final List<dynamic> results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      final payload = item[0] == 0x01
          ? utf8.decode(item.sublist(1))
          : utf8.decode(item);
      try {
        results.add(jsonDecode(payload));
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}

class _TrackingEncryption implements Encryption {
  final List<_TrackingSessionKeys> openInvocations = <_TrackingSessionKeys>[];
  final List<String> removedSessionIds = <String>[];
  final Map<String, SessionEncryption> sessionEncryptions =
      <String, SessionEncryption>{};
  final EncryptionCache cache = EncryptionCache();

  @override
  Future<dynamic> openEncryption(Uint8List? dataKey) async {
    final key = dataKey == null
        ? Uint8List.fromList(const [0])
        : Uint8List.fromList(dataKey);
    openInvocations.add(_TrackingSessionKeys(key));
    return _TrackingEncryptor(key);
  }

  @override
  void setSessionEncryption(String sessionId, SessionEncryption enc) {
    sessionEncryptions[sessionId] = enc;
  }

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return sessionEncryptions[sessionId];
  }

  @override
  void removeSessionEncryption(String sessionId) {
    sessionEncryptions.remove(sessionId);
    removedSessionIds.add(sessionId);
  }

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {
    for (final entry in sessions.entries) {
      final sessionId = entry.key;
      sessionEncryptions[sessionId] = SessionEncryption(
        sessionId: sessionId,
        encryptor: _TrackingEncryptor(entry.value ?? Uint8List(0)),
        decryptor: _TrackingEncryptor(entry.value ?? Uint8List(0)),
        cache: cache,
      );
    }
  }

  @override
  Future<Uint8List?> decryptEncryptionKey(String encryptedKey) async {
    if (encryptedKey == 'dek:one') {
      return Uint8List.fromList([1, 2, 3]);
    }
    if (encryptedKey == 'dek:two') {
      return Uint8List.fromList([4, 5, 6]);
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _encryptedPayload(Map<String, dynamic> value) {
  final bytes = utf8.encode(jsonEncode(value));
  final wrapped = Uint8List(bytes.length + 1);
  wrapped[0] = 0x01;
  wrapped.setRange(1, wrapped.length, bytes);
  return base64Encode(wrapped);
}

void main() {
  group('Sync session DEK rotation', () {
    late Sync sync;
    late _TrackingEncryption encryption;

    setUp(() async {
      sync = createTestSync();
      encryption = _TrackingEncryption();
      sync.encryption = encryption;
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.clear();
    });

    tearDown(() {
      ApiClient().dispose();
    });

    test('reopens and replaces session encryption when DEK changes', () async {
      final metadata = _encryptedPayload(<String, dynamic>{'path': '/project'});
      final agentState = _encryptedPayload(<String, dynamic>{
        'state': 'active',
      });

      Response<dynamic> serveSessions(String dek) {
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/v2/sessions'),
          statusCode: 200,
          data: <String, dynamic>{
            'sessions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'rotating-session',
                'seq': 1,
                'createdAt': 1700000000000,
                'updatedAt': 1700000000000,
                'active': false,
                'activeAt': 1700000000000,
                'metadata': metadata,
                'metadataVersion': 1,
                'agentState': agentState,
                'agentStateVersion': 1,
                'dataEncryptionKey': dek,
                'lastSeq': 1,
              },
            ],
            'hasNext': false,
            'nextCursor': null,
          },
        );
      }

      var requestCount = 0;
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v2/sessions') {
              requestCount += 1;
              handler.resolve(
                requestCount == 1
                    ? serveSessions('dek:one')
                    : serveSessions('dek:two'),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
                data: <String, dynamic>{},
              ),
            );
          },
        ),
      );

      await sync.fetchSessions();
      final firstSessionEncryption = sync.encryption.getSessionEncryption(
        'rotating-session',
      );

      await sync.fetchSessions();
      final secondSessionEncryption = sync.encryption.getSessionEncryption(
        'rotating-session',
      );

      expect(firstSessionEncryption, isNotNull);
      expect(secondSessionEncryption, isNotNull);
      expect(
        identical(firstSessionEncryption, secondSessionEncryption),
        isFalse,
      );
      expect(encryption.openInvocations.length, equals(2));
      expect(
        encryption.openInvocations[0].key,
        equals(Uint8List.fromList([1, 2, 3])),
      );
      expect(
        encryption.openInvocations[1].key,
        equals(Uint8List.fromList([4, 5, 6])),
      );
      expect(encryption.removedSessionIds, contains('rotating-session'));
    });
  });
}
