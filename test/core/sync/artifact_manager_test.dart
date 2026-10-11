import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/artifact_encryption.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/sync/artifact_manager.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

class _Encryption extends Fake implements Encryption {
  _Encryption(this.key);
  final Uint8List key;

  @override
  Future<Uint8List?> decryptEncryptionKey(String encrypted) async => key;
}

class _Api extends Fake implements ApiClient {
  late Map<String, dynamic> artifact;
  Map<String, dynamic>? sent;
  dynamic updateResult = <String, dynamic>{'success': true};
  int reads = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    reads++;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: path == '/v1/artifacts'
          ? <String, dynamic>{
              'artifacts': [artifact],
            }
          : artifact,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    sent = data as Map<String, dynamic>;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: updateResult,
    );
  }

  @override
  bool isSuccess(Response<dynamic> response) => response.statusCode == 200;
}

void main() {
  late _Api api;
  late ArtifactEncryption cipher;
  late ArtifactManager manager;
  late InvalidateSync refresh;
  late Map<String, dynamic> header;
  int refreshes = 0;

  setUp(() async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    cipher = ArtifactEncryption(key);
    api = _Api();
    header = <String, dynamic>{
      'title': 'Before',
      'sessions': ['session-1', 'session-2'],
      'draft': true,
      'futureMetadata': <String, dynamic>{
        'tags': ['keep'],
      },
    };
    api.artifact = <String, dynamic>{
      'id': 'a1',
      'header': await cipher.encryptHeader(header),
      'body': await cipher.encryptBody({'body': 'Before body'}),
      'headerVersion': 3,
      'bodyVersion': 4,
      'dataEncryptionKey': 'fake-key',
      'seq': 1,
      'createdAt': 1,
      'updatedAt': 2,
    };
    refreshes = 0;
    refresh = InvalidateSync(() async {
      refreshes++;
    });
    manager = ArtifactManager(
      encryption: _Encryption(key),
      client: api,
      artifactsSyncGetter: () => refresh,
      onDataChanged: (_) {},
    );
    await manager.fetchArtifactsList();
  });

  tearDown(() {
    refresh.dispose();
  });

  test(
    'update preserves full encrypted header and expected versions',
    () async {
      await manager.updateArtifact('a1', 'After', 'After body');
      final sent = api.sent!;
      expect(
        await cipher.decryptHeader(sent['header'] as String),
        <String, dynamic>{...header, 'title': 'After'},
      );
      expect(await cipher.decryptBody(sent['body'] as String), {
        'body': 'After body',
      });
      expect(sent['expectedHeaderVersion'], 3);
      expect(sent['expectedBodyVersion'], 4);
      // Simulate the server storing the encrypted update, then read it back.
      api.artifact = <String, dynamic>{
        ...api.artifact,
        'header': sent['header'],
        'body': sent['body'],
        'headerVersion': 4,
        'bodyVersion': 5,
      };
      await manager.fetchArtifactsList();
      expect(manager.artifacts.single.title, 'After');
      expect(manager.artifacts.single.sessions, ['session-1', 'session-2']);
      expect(manager.artifacts.single.draft, isTrue);
      expect((await manager.fetchArtifactWithBody('a1'))?.sessions, [
        'session-1',
        'session-2',
      ]);
      expect((await manager.fetchArtifactWithBody('a1'))?.draft, isTrue);
      await manager.updateArtifact('a1', 'Again', 'After body');
      expect(
        await cipher.decryptHeader(api.sent!['header'] as String),
        <String, dynamic>{...header, 'title': 'Again'},
      );
      expect(api.sent!['expectedHeaderVersion'], 4);
    },
  );

  test('explicit 2xx rejection throws and does not refresh', () async {
    api.updateResult = <String, dynamic>{
      'success': false,
      'error': 'version-mismatch',
    };
    await expectLater(
      manager.updateArtifact('a1', 'After', 'After body'),
      throwsStateError,
    );
    expect(refreshes, 0);
  });

  test('explicit error without success rejects the save', () async {
    api.updateResult = <String, dynamic>{'error': 'version-mismatch'};
    await expectLater(
      manager.updateArtifact('a1', 'After', null),
      throwsStateError,
    );
    expect(refreshes, 0);
  });

  test('2xx without success field remains accepted', () async {
    api.updateResult = <String, dynamic>{};
    await manager.updateArtifact('a1', 'After', null);
  });

  test('successful envelope may include an empty error field', () async {
    api.updateResult = <String, dynamic>{'success': true, 'error': ''};
    await manager.updateArtifact('a1', 'After', null);
  });
}
