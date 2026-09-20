import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

class _PreviewCipher implements SessionEncryption {
  Completer<dynamic>? pending;
  @override
  Future<dynamic> decryptRaw(String value) async =>
      pending == null ? jsonDecode(value) : await pending!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Encryption implements Encryption {
  final cipher = _PreviewCipher();
  @override
  SessionEncryption? getSessionEncryption(String id) => cipher;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _preview(String text) => {
  'role': 'agent',
  'content': {
    'type': 'codex',
    'data': {
      'type': 'model-output',
      'streamId': 'stream',
      'fullText': text,
      'isStreaming': true,
    },
  },
};

void main() {
  late Sync instance;
  late _Encryption encryption;
  setUp(() {
    instance = createTestSync();
    encryption = _Encryption();
    instance.encryption = encryption;
    instance.isInitialized = true;
    InvalidateSync.isBackgrounded = false;
    instance.prepareSessionVisibility('preview-session');
    instance.testSetSessionMessages('preview-session', []);
  });
  tearDown(() async {
    await instance.onSessionInvisible('preview-session');
    await instance.onSessionInvisible('other');
    instance.isInitialized = false;
  });

  Future<void> deliver(String text) async {
    instance.handleEphemeralUpdate({
      'type': 'message-stream',
      'id': 'preview-session',
      'message': jsonEncode(_preview(text)),
    });
    await Future<void>.delayed(Duration.zero);
  }

  test('socket preview is visible but never persisted; final wins', () async {
    final user = {'id': 'user', 'localId': 'canonical', 'role': 'user'};
    instance.testSetSessionMessages('preview-session', [user]);
    await deliver('hello');
    await deliver('hello world');
    expect(instance.messagesForSession('preview-session'), hasLength(2));
    expect(
      instance.messagesForSession('preview-session').last['content'],
      'hello world',
    );
    expect(instance.sessionMessages['preview-session'], [user]);
    final finalRow = {
      'id': 'wire-id',
      'localId': 'wire-local',
      'role': 'agent',
      'kind': 'text',
      'streamId': 'stream',
      'content': 'final answer',
    };
    instance.testSetSessionMessages('preview-session', [user, finalRow]);
    await deliver('late preview after completion');
    expect(instance.messagesForSession('preview-session'), [user, finalRow]);
    expect(instance.sessionMessages['preview-session'], [user, finalRow]);
  });

  test(
    'decrypt finishing after leaving and reopening chat is discarded',
    () async {
      encryption.cipher.pending = Completer<dynamic>();
      instance.handleEphemeralUpdate({
        'type': 'message-stream',
        'id': 'preview-session',
        'message': 'paused',
      });
      instance.prepareSessionVisibility('other');
      instance.prepareSessionVisibility('preview-session');
      encryption.cipher.pending!.complete(_preview('stale'));
      await Future<void>.delayed(Duration.zero);
      expect(instance.messagesForSession('preview-session'), isEmpty);
    },
  );

  test('old decryptions cannot exhaust the next visible chat budget', () async {
    final pending = Completer<dynamic>();
    encryption.cipher.pending = pending;
    for (var i = 0; i < 4; i++) {
      instance.handleEphemeralUpdate({
        'type': 'message-stream',
        'id': 'preview-session',
        'message': 'paused',
      });
    }
    instance.prepareSessionVisibility('other');
    instance.prepareSessionVisibility('preview-session');
    encryption.cipher.pending = null;
    await deliver('current preview');
    pending.complete(_preview('stale'));
    await Future<void>.delayed(Duration.zero);
    expect(
      instance.messagesForSession('preview-session').single['content'],
      'current preview',
    );
  });

  test('decrypt finishing after runtime shutdown is discarded', () async {
    encryption.cipher.pending = Completer<dynamic>();
    instance.handleEphemeralUpdate({
      'type': 'message-stream',
      'id': 'preview-session',
      'message': 'paused',
    });
    await instance.shutdown();
    encryption.cipher.pending!.complete(_preview('wrong account'));
    await Future<void>.delayed(Duration.zero);
    expect(instance.messagesForSession('preview-session'), isEmpty);
  });
}
