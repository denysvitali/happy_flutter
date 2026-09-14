import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/core/sync/settings_manager.dart';

class _Encryption implements Encryption {
  @override
  Future<String> encryptRaw(dynamic value) async => jsonEncode(value);
  @override
  Future<dynamic> decryptRaw(String value) async => jsonDecode(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends Fake implements ApiClient {
  final writes = <Map<String, dynamic>>[];
  Future<Response<dynamic>> Function()? respond;
  int reads = 0;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
  }) {
    writes.add(Map<String, dynamic>.from(data as Map));
    return respond!();
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    reads++;
    return respond!();
  }

  @override
  bool isSuccess(Response<dynamic> response) => response.statusCode == 200;
}

Response<dynamic> _response(Map<String, dynamic> data) => Response<dynamic>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: '/v1/account/settings'),
);

void main() {
  late _Api api;
  late SettingsManager manager;
  late InvalidateSync idle;

  setUp(() {
    api = _Api();
    idle = InvalidateSync(() async {});
    manager = SettingsManager(
      encryption: _Encryption(),
      client: api,
      nativeUpdateFreshnessMs: 0,
      isTransientConnectionError: (_) => false,
      settingsSyncGetter: () => idle,
      profileSyncGetter: () => idle,
      purchasesSyncGetter: () => idle,
      onDataChanged: (_) {},
    );
  });

  tearDown(() => idle.dispose());

  testWidgets('write can finish after the old 10 second wrapper deadline', (
    tester,
  ) async {
    await manager.applySettings({'lastUsedAgent': 'codex'});
    final response = Completer<Response<dynamic>>();
    api.respond = () => response.future;
    var completed = false;
    final write = manager.syncSettings().then((_) => completed = true);
    await tester.pump(const Duration(seconds: 11));
    expect(completed, isFalse);
    response.complete(_response({'success': true, 'settingsVersion': 1}));
    await tester.pump();
    await write;
    expect(manager.pendingSettings, isEmpty);
    expect(manager.settingsVersion, 1);
  });

  test('write deadline failure reaches queue and keeps pending edits', () async {
    await manager.applySettings({'lastUsedAgent': 'codex'});
    api.respond = () async => throw DioException(
      requestOptions: RequestOptions(path: '/v1/account/settings'),
      type: DioExceptionType.cancel,
      error: 'HTTP request deadline exceeded',
    );
    await expectLater(manager.syncSettings(), throwsA(isA<DioException>()));
    expect(manager.pendingSettings['lastUsedAgent'], 'codex');
    api.respond = () async => _response({
      'success': true, 'settingsVersion': 1,
    });
    await manager.syncSettings();
    expect(manager.pendingSettings, isEmpty);
    expect(api.writes, hasLength(2));
  });

  test('POST completion preserves edits made while awaiting response', () async {
    await manager.applySettings({'lastUsedAgent': 'claude'});
    final response = Completer<Response<dynamic>>();
    api.respond = () => response.future;
    final write = manager.syncSettings();
    await Future<void>.delayed(Duration.zero);
    await manager.applySettings({'lastUsedAgent': 'codex'});
    response.complete(_response({'success': true, 'settingsVersion': 1}));
    await write;
    expect(manager.settingsSnapshot.lastUsedAgent, 'codex');
    expect(manager.pendingSettings['lastUsedAgent'], 'codex');
    api.respond = () async => _response({
      'success': true, 'settingsVersion': 2,
    });
    await manager.syncSettings();
    expect(api.writes.last['expectedVersion'], 1);
    expect(manager.pendingSettings, isEmpty);
  });

  test('conflict rebases pending edits and fails for automatic retry', () async {
    await manager.applySettings({'lastUsedAgent': 'codex'});
    api.respond = () async => _response({
      'error': 'version-mismatch',
      'currentVersion': 7,
      'currentSettings': jsonEncode({'lastUsedAgent': 'claude'}),
    });
    await expectLater(manager.syncSettings(), throwsA(isA<StateError>()));
    expect(manager.settingsVersion, 7);
    expect(manager.settingsSnapshot.lastUsedAgent, 'codex');
    expect(api.reads, 0);
    api.respond = () async => _response({
      'success': true, 'settingsVersion': 8,
    });
    await manager.syncSettings();
    expect(api.writes.last['expectedVersion'], 7);
    expect(manager.pendingSettings, isEmpty);
  });

  test('late POST cannot restore settings after runtime reset', () async {
    await manager.applySettings({'lastUsedAgent': 'codex'});
    final response = Completer<Response<dynamic>>();
    api.respond = () => response.future;
    final write = manager.syncSettings();
    await Future<void>.delayed(Duration.zero);
    manager.clear();
    response.complete(_response({'success': true, 'settingsVersion': 5}));
    await write;
    expect(manager.settingsVersion, 0);
    expect(manager.pendingSettings, isEmpty);
    expect(manager.lastSettingsPostAtMs, isNull);
  });

  test('GET completion overlays edits made during the fetch', () async {
    final response = Completer<Response<dynamic>>();
    api.respond = () => response.future;
    final read = manager.syncSettings();
    await manager.applySettings({'lastUsedAgent': 'codex'});
    response.complete(_response({
      'settings': jsonEncode({'lastUsedAgent': 'claude'}),
      'settingsVersion': 3,
    }));
    await read;
    expect(manager.settingsSnapshot.lastUsedAgent, 'codex');
    expect(manager.pendingSettings['lastUsedAgent'], 'codex');
  });
}
