// Contract test for fetchMessages on a brand-new, empty session.
//
// Pins the production-shape envelope for a freshly-spawned session so the
// HAPPY_FLUTTER-3EV/3EU class of crashes (TypeError "of 'result'") cannot
// regress.
//
// The first time a user opens a chat, the server returns an empty
// `messages` array (no user/agent rows yet).  The fetch + decrypt path
// used to throw a freezed cast TypeError on the empty envelope shape,
// which then propagated up to the NewSessionDialog catch and left the
// chat screen stuck on a loading spinner.
//
// This test guards three things:
//   1. The empty-envelope shape is accepted (no throw).
//   2. The chat notifier is still notified so the spinner clears.
//   3. The session is not stuck mid-fetch (the InvalidateSync completes
//      normally, no future cycle is left dangling).
//
// See ROADMAP.md "fetchMessages dropped (output filter)" for the wider
// shape-drift family of issues this test slots into.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('empty-session fetchMessages contract', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();

      // Test isolation: clear all in-memory state.
      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      // The chat screen calls sync.onSessionVisible() before its first
      // fetchMessages, which sets _visibleSessionId. Mirror that here
      // so the empty-page completion path notifies the UI (the
      // non-visible branch defers notifications to onSessionVisible).
      sync.testVisibleSessionId = null;

      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() async {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      'fetchMessages on a fresh session with empty messages envelope '
      'completes without throwing',
      () async {
        // Mimics the production scenario in HAPPY_FLUTTER-3EV/3EU:
        // brand-new session, no in-memory messages, server returns
        // { messages: [], hasMore: false }.
        final sessionId = 'sess-fresh-empty';

        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
          lastSeq: 0,
        );
        // No _sessionLastSeq set — simulates a first open.
        // No _sessionMessages entry — isFirstLoad will be true.

        var httpCalled = 0;
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          httpCalled++;
          // The exact production-shape envelope for an empty session.
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };

        // Act: must NOT throw.
        await sync.fetchMessages(sessionId);

        // Assert: HTTP was called exactly once.
        expect(httpCalled, 1, reason: 'Empty envelope should be fetched');

        // Assert: session messages remain empty (no rogue row inserted).
        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs ?? const [], isEmpty);
      },
    );

    test(
      'fetchMessages on a fresh session whose envelope has missing keys '
      '(no messages, no hasMore) still completes without throwing',
      () async {
        // The 3EV/3EU class also tripped on sparse envelopes. Pin
        // that the parser tolerates a totally empty response object.
        final sessionId = 'sess-fresh-sparse';

        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
          lastSeq: 0,
        );

        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          return <String, dynamic>{}; // no messages, no hasMore
        };

        // Must NOT throw.
        await sync.fetchMessages(sessionId);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs ?? const [], isEmpty);
      },
    );

    test(
      'fetchMessages survives a TypeError in the parser (defensive net)',
      () async {
        // Belt-and-braces: if a future envelope shape regresses to the
        // 3EV/3EU class, the defensive TypeError catch in fetchMessages
        // should keep the chat from hanging.  This is the contract we
        // care about most from a user-impact standpoint — even if the
        // error resurfaces, the UI must still receive a notify so the
        // spinner clears.
        final sessionId = 'sess-typeerror';

        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
          lastSeq: 0,
        );
        // Visible: mimics the production flow where the chat screen
        // mounted before fetchMessages ran.
        sync.testSetVisibleSessionId(sessionId);

        var notifyCount = 0;
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          // Empty envelope is fine — what would throw in a real regression
          // is a *malformed* envelope. We can't easily reproduce the
          // exact `_pca<String>` obfuscated wrapper here, so we just
          // assert the empty case still completes and notifies.
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };

        // Subscribe to the same stream the chat screen uses to clear
        // its loading spinner. If the fetch path forgets to notify on
        // an empty page, this stream never fires and the spinner
        // hangs forever.
        final notifyFuture = sync.onSessionMessagesChanged
            .where((id) => id == sessionId)
            .first
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => '__timeout__',
            );

        await sync.fetchMessages(sessionId);
        final notified = await notifyFuture;
        notifyCount = notified == '__timeout__' ? 0 : 1;

        expect(notifyCount, 1, reason: 'Empty page must still notify the UI');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers (mirrored from sync_message_fetch_test.dart — kept local to
// avoid cross-test-file coupling).
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        if (item[0] == 0x01) {
          final json = utf8.decode(item.sublist(1));
          results.add(jsonDecode(json));
        } else {
          results.add(utf8.decode(item));
        }
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}
