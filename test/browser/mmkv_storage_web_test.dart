@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb.dart';
import 'package:happy_flutter/core/services/mmkv_storage_web.dart';

class _CommitFailureDatabase implements Database {
  @override
  Transaction transaction(Object stores, String mode) => _CommitFailure();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CommitFailure implements Transaction {
  @override
  ObjectStore objectStore(String name) => _AcceptedPut();
  @override
  Future<Database> get completed =>
      Future<Database>.error(StateError('transaction aborted at commit'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AcceptedPut implements ObjectStore {
  @override
  Future<Object> put(Object value, [Object? key]) async => key!;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('outbox write failure propagates and retains committed cache', () async {
    final db = await idbFactoryMemory.open(
      'outbox-write-contract',
      version: 1,
      onUpgradeNeeded: (event) => event.database.createObjectStore('kv'),
    );
    final storage = MMKVStorage.testConstructor(database: db);
    await storage.saveOutboxEntries('committed');
    db.close();
    await expectLater(
      storage.saveOutboxEntries('uncommitted'),
      throwsA(anything),
    );
    expect(await storage.getOutboxEntries(), 'committed');
  });

  test('transaction abort propagates even after put succeeds', () async {
    final storage = MMKVStorage.testConstructor(
      database: _CommitFailureDatabase(),
    );
    await expectLater(storage.saveOutboxEntries('pending'), throwsStateError);
    expect(await storage.getOutboxEntries(), isNull);
  });

  test('generic durable writes propagate commit failure', () async {
    final storage = MMKVStorage.testConstructor(
      database: _CommitFailureDatabase(),
    );
    await expectLater(
      storage.setStringDurable('journal', 'edit'),
      throwsStateError,
    );
    expect(storage.getString('journal'), isNull);
  });

  test('generic durable removal failure retains committed cache', () async {
    final db = await idbFactoryMemory.open(
      'generic-remove-contract',
      version: 1,
      onUpgradeNeeded: (event) => event.database.createObjectStore('kv'),
    );
    final storage = MMKVStorage.testConstructor(database: db);
    await storage.setStringDurable('journal', 'committed');
    db.close();
    await expectLater(storage.removeKeyDurable('journal'), throwsA(anything));
    expect(storage.getString('journal'), 'committed');
  });

  test('unavailable durable storage never claims an outbox enqueue', () async {
    final storage = MMKVStorage.testConstructor();
    await expectLater(storage.saveOutboxEntries('pending'), throwsA(anything));
    expect(await storage.getOutboxEntries(), isNull);
  });
}
