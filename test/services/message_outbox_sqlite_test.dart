/// Tests for the append-only SQLite-style message outbox.
///
/// These tests use the in-memory store impl shipped alongside
/// [SqliteMessageOutbox] — once the `sqlite3` package is added to
/// `pubspec.yaml` the same tests can be re-pointed at a real
/// `:memory:` database without changing assertions.
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/message_outbox_sqlite.dart';

OutboxEntry _entry(
  String localId, {
  String session = 'sess-1',
  int retryCount = 0,
  int queuedAt = 1000,
}) {
  return OutboxEntry(
    localId: localId,
    sessionId: session,
    text: 'hi',
    encryptedContent: 'cipher',
    rawRecord: const {'role': 'user'},
    queuedAt: queuedAt,
    retryCount: retryCount,
  );
}

void main() {
  group('InMemoryOutboxStore', () {
    test('appends each event and returns them in insertion order',
        () async {
      final store = InMemoryOutboxStore();
      await store.open();
      await store.appendAdd(_entry('a'));
      await store.appendRetry('a', 1);
      await store.appendSent('a');
      final all = await store.readAll();
      expect(all.length, 3);
      expect(all.map((e) => e.kind).toList(), ['add', 'retry', 'sent']);
    });

    test('compact drops events for terminal messages', () async {
      final store = InMemoryOutboxStore();
      await store.open();
      await store.appendAdd(_entry('a'));
      await store.appendSent('a');
      await store.appendAdd(_entry('b'));
      store.compact();
      final all = await store.readAll();
      expect(all.length, 1);
      expect(all.first.localId, 'b');
    });
  });

  group('SqliteMessageOutbox.restoreAndFlush — log fold', () {
    test('rebuilds live entries after add events only', () async {
      final store = InMemoryOutboxStore();
      await store.open();
      await store.appendAdd(_entry('a', queuedAt: 100));
      await store.appendAdd(_entry('b', queuedAt: 200));

      final outbox = SqliteMessageOutbox(
        store: store,
        deliverOverride: (_) async => true,
      )..configure(deliver: (_) async => true);
      await outbox.restoreAndFlush();
      // The folder should have rebuilt both entries.
      final ids = outbox.entries.map((e) => e.localId).toSet();
      expect(ids, {'a', 'b'});
    });

    test('drops entries terminated by sent or failed', () async {
      final store = InMemoryOutboxStore();
      await store.open();
      await store.appendAdd(_entry('a'));
      await store.appendSent('a');
      await store.appendAdd(_entry('b'));
      await store.appendFailed('b');
      await store.appendAdd(_entry('c'));

      final outbox = SqliteMessageOutbox(
        store: store,
        deliverOverride: (_) async => true,
      )..configure(deliver: (_) async => true);
      await outbox.restoreAndFlush();
      final ids = outbox.entries.map((e) => e.localId).toSet();
      expect(ids, {'c'});
    });

    test('retry events update retry count', () async {
      final store = InMemoryOutboxStore();
      await store.open();
      await store.appendAdd(_entry('a', retryCount: 0));
      await store.appendRetry('a', 1);
      await store.appendRetry('a', 2);

      final outbox = SqliteMessageOutbox(
        store: store,
        deliverOverride: (_) async => true,
      )..configure(deliver: (_) async => true);
      await outbox.restoreAndFlush();
      final entry = outbox.entries.firstWhere((e) => e.localId == 'a');
      expect(entry.retryCount, 2);
    });
  });

  group('debugFoldEvents (regression-safe pure folder)', () {
    test('folds raw add+retry+sent events', () {
      final folded = debugFoldEvents([
        {
          'seq': 1,
          'ts_ms': 0,
          'local_id': 'a',
          'session_id': 'sess',
          'kind': 'add',
          'payload': _entry('a').toJson(),
        },
        {
          'seq': 2,
          'ts_ms': 1,
          'local_id': 'a',
          'session_id': 'sess',
          'kind': 'retry',
          'payload': {'retryCount': 5},
        },
      ]);
      expect(folded.length, 1);
      expect(folded['a']?.retryCount, 5);
    });

    test('a sent event removes the corresponding live entry', () {
      final folded = debugFoldEvents([
        {
          'seq': 1,
          'ts_ms': 0,
          'local_id': 'x',
          'session_id': 'sess',
          'kind': 'add',
          'payload': _entry('x').toJson(),
        },
        {
          'seq': 2,
          'ts_ms': 1,
          'local_id': 'x',
          'session_id': 'sess',
          'kind': 'sent',
        },
      ]);
      expect(folded, isEmpty);
    });
  });

  test('kUseSqliteOutbox defaults to false in production', () {
    expect(kUseSqliteOutbox, false);
  });
}
