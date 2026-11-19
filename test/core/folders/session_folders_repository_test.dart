import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/kv_api.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/folders/session_folders_doc.dart';
import 'package:happy_flutter/core/folders/session_folders_envelope.dart';
import 'package:happy_flutter/core/folders/session_folders_repository.dart';
import 'package:happy_flutter/core/models/kv.dart';

Uint8List _randomKey() {
  final random = Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
}

/// In-memory KV with the server's compare-and-set semantics.
class _FakeKv implements KvStore {
  String? value;
  int version = -1;
  int mutations = 0;

  /// Runs before a mutation is checked, to simulate a concurrent writer.
  void Function(_FakeKv kv)? beforeMutate;

  void put(String? next) {
    value = next;
    version = version < 0 ? 0 : version + 1;
  }

  @override
  Future<KvItem?> get(String key) async {
    final current = value;
    if (current == null) return null;
    return KvItem(key: key, value: current, version: version);
  }

  @override
  Future<KvMutateResponse> mutate(List<KvMutation> mutations) async {
    this.mutations++;
    beforeMutate?.call(this);
    final m = mutations.single;
    final exists = version >= 0;
    final ok = m.version == -1 ? !exists : m.version == version;
    if (!ok) {
      return KvMutateErrorResponse([
        KvMutateError(
          key: m.key,
          error: 'version-mismatch',
          version: version,
          value: value,
        ),
      ]);
    }
    put(m.value);
    return KvMutateSuccessResponse([
      KvMutateResult(key: m.key, version: version),
    ]);
  }
}

class _Keyring implements FolderKeyring {
  _Keyring(this.encryption, [this.machines = const {}]);

  final Encryption encryption;
  final Map<String, Uint8List> machines;
  late final EncryptionFolderKeyring _inner = EncryptionFolderKeyring(
    encryption,
    () => machines,
  );

  @override
  Map<String, Uint8List> get machineKeys => machines;

  @override
  Future<Uint8List?> openBox(Uint8List wrapped) => _inner.openBox(wrapped);

  @override
  Future<Uint8List> sealBox(Uint8List key) => _inner.sealBox(key);

  @override
  Future<Object?> openLegacy(Uint8List sealed) => _inner.openLegacy(sealed);

  @override
  Future<Uint8List> sealLegacy(Object json) => _inner.sealLegacy(json);
}

Map<String, dynamic> _envelope(String base64Value) =>
    jsonDecode(utf8.decode(Base64Utils.decode(base64Value)))
        as Map<String, dynamic>;

String _encodeEnvelope(Map<String, dynamic> env) =>
    Base64Utils.encode(Uint8List.fromList(utf8.encode(jsonEncode(env))));

void main() {
  late Encryption account;
  late Encryption otherAccount;
  final machineKey = _randomKey();

  setUpAll(() async {
    account = await Encryption.create(_randomKey());
    otherAccount = await Encryption.create(_randomKey());
  });

  SessionFoldersRepository repo(
    _FakeKv kv, {
    Encryption? encryption,
    Map<String, Uint8List> machines = const {},
  }) => SessionFoldersRepository(
    kv: kv,
    codec: SessionFoldersCodec(_Keyring(encryption ?? account, machines)),
  );

  const work = CreateFolder(id: 'f0123456789abcdef', name: 'Work');

  test('first write creates the document with every wrap', () async {
    final kv = _FakeKv();
    final r = repo(kv, machines: {'m1': machineKey});
    final written = await r.write(work, await r.load());
    expect(written.version, 0);
    expect(written.doc.folders.keys, ['f0123456789abcdef']);

    final env = _envelope(kv.value!);
    expect(env['v'], 1);
    final keys = env['keys'] as Map<String, dynamic>;
    expect(keys.keys, containsAll(['account', 'legacy', 'machines']));
    // account = 0x00 ‖ box, like a session dataEncryptionKey.
    expect(Base64Utils.decode(keys['account'] as String)[0], 0);
    expect((keys['machines'] as Map).keys, ['m1']);
    // data = AES-GCM data-key JSON: 0x00 ‖ nonce ‖ ciphertext.
    expect(Base64Utils.decode(env['data'] as String)[0], 0);

    final loaded = await repo(kv).load();
    expect(loaded.access, FolderAccess.ready);
    expect(loaded.doc, written.doc);
  });

  test('crypto round trip: every wrap opens the same folder key', () async {
    final kv = _FakeKv();
    await repo(
      kv,
      machines: {'m1': machineKey},
    ).write(work, FolderSnapshot.absent);
    final keys = _envelope(kv.value!)['keys'] as Map<String, dynamic>;

    final viaAccount = await account.decryptEncryptionKey(
      keys['account'] as String,
    );
    final legacy = (await SecretBoxEncryption(
      account.legacySecretKey,
    ).decrypt([Base64Utils.decode(keys['legacy'] as String)])).single;
    final machine = (await AES256Encryption(machineKey).decrypt([
      Base64Utils.decode((keys['machines'] as Map)['m1'] as String),
    ])).single;
    final fk = Base64Utils.encode(viaAccount!);
    expect((legacy as Map)['k'], fk);
    expect((machine as Map)['k'], fk);

    final data = (await AES256Encryption(viaAccount).decrypt([
      Base64Utils.decode(_envelope(kv.value!)['data'] as String),
    ])).single;
    expect(data, {
      'folders': {
        'f0123456789abcdef': {'name': 'Work', 'parent': null, 'anchor': null},
      },
      'sessions': <String, dynamic>{},
    });
  });

  test('a reader holding only a machine key opens its machine wrap', () async {
    final kv = _FakeKv();
    await repo(
      kv,
      machines: {'m1': machineKey},
    ).write(work, FolderSnapshot.absent);
    final daemonLike = await repo(
      kv,
      encryption: otherAccount,
      machines: {'m1': machineKey},
    ).load();
    expect(daemonLike.access, FolderAccess.ready);
    expect(daemonLike.doc.folders['f0123456789abcdef']!.name, 'Work');
  });

  test(
    'an undecryptable document shows nothing and is never written',
    () async {
      final kv = _FakeKv();
      await repo(kv).write(work, FolderSnapshot.absent);
      final stranger = repo(kv, encryption: otherAccount);
      final loaded = await stranger.load();
      expect(loaded.access, FolderAccess.unreadable);
      expect(loaded.doc.isEmpty, isTrue);
      await expectLater(
        stranger.write(const DeleteFolder('f0123456789abcdef'), loaded),
        throwsA(isA<FolderRuleException>()),
      );
      expect(kv.mutations, 1);

      kv.put(base64Encode(utf8.encode('not json')));
      expect((await repo(kv).load()).access, FolderAccess.unreadable);
      kv.put(_encodeEnvelope({'v': 1, 'keys': 'x', 'data': 1}));
      expect((await repo(kv).load()).access, FolderAccess.unreadable);
    },
  );

  test('a higher version is shown read-only', () async {
    final kv = _FakeKv();
    await repo(kv).write(work, FolderSnapshot.absent);
    kv.put(_encodeEnvelope({..._envelope(kv.value!), 'v': 2}));
    final loaded = await repo(kv).load();
    expect(loaded.access, FolderAccess.readOnly);
    expect(loaded.doc.folders, hasLength(1));
    await expectLater(
      repo(kv).write(const DeleteFolder('f0123456789abcdef'), loaded),
      throwsA(
        isA<FolderRuleException>().having(
          (e) => e.rule,
          'rule',
          FolderRule.readOnly,
        ),
      ),
    );
  });

  test('a lost race re-applies the edit to the winning document', () async {
    final kv = _FakeKv();
    final r = repo(kv);
    final start = await r.write(work, FolderSnapshot.absent);

    // Another device adds a folder after our read, before our write.
    final theirs = await repo(
      kv,
    ).write(const CreateFolder(id: 'f1111111111111111', name: 'Home'), start);
    expect(theirs.version, 1);

    final ours = await r.write(
      const CreateFolder(id: 'f2222222222222222', name: 'Play'),
      start,
    );
    expect(ours.version, 2);
    expect(
      ours.doc.folders.keys,
      unorderedEquals([
        'f0123456789abcdef',
        'f1111111111111111',
        'f2222222222222222',
      ]),
    );
    expect((await r.load()).doc, ours.doc);
  });

  test('a re-applied edit that the winner refuses fails', () async {
    final kv = _FakeKv();
    final r = repo(kv);
    final start = await r.write(work, FolderSnapshot.absent);
    await repo(
      kv,
    ).write(const CreateFolder(id: 'f1111111111111111', name: 'Home'), start);
    await expectLater(
      r.write(const CreateFolder(id: 'f2222222222222222', name: 'home'), start),
      throwsA(
        isA<FolderRuleException>().having(
          (e) => e.rule,
          'rule',
          FolderRule.duplicateName,
        ),
      ),
    );
  });

  test('gives up after five lost races', () async {
    final kv = _FakeKv();
    final r = repo(kv);
    await r.write(work, FolderSnapshot.absent);
    final snapshot = await r.load();
    kv.beforeMutate = (kv) => kv.version++;
    await expectLater(
      r.write(
        const RenameFolder(id: 'f0123456789abcdef', name: 'Jobs'),
        snapshot,
      ),
      throwsA(isA<FolderConflictException>()),
    );
    expect(kv.mutations, 1 + SessionFoldersRepository.maxAttempts);
  });

  test('a deleted key (null value) is recreated at its version', () async {
    final kv = _FakeKv()
      ..version = 3
      ..value = null;
    final r = repo(kv);
    final written = await r.write(work, await r.load());
    expect(written.version, 4);
    expect(kv.mutations, 2);
  });

  test('loading adds missing wraps once, keeping the rest', () async {
    final kv = _FakeKv();
    await repo(kv).write(work, FolderSnapshot.absent);
    final before = _envelope(kv.value!);
    expect((before['keys'] as Map).containsKey('machines'), isFalse);

    final r = repo(kv, machines: {'m1': machineKey});
    final added = await r.write(null, await r.load());
    expect(added.version, 1);
    final after = _envelope(kv.value!)['keys'] as Map<String, dynamic>;
    expect(after['account'], (before['keys'] as Map)['account']);
    expect(after['legacy'], (before['keys'] as Map)['legacy']);
    expect((after['machines'] as Map).keys, ['m1']);

    final again = await r.write(null, added);
    expect(again.version, 1);
    expect(kv.mutations, 2);
    // Nothing to wrap when there is no document yet.
    final empty = _FakeKv();
    await repo(
      empty,
      machines: {'m1': machineKey},
    ).write(null, FolderSnapshot.absent);
    expect(empty.mutations, 0);
  });

  test('decodes kv-batch-update values', () async {
    final kv = _FakeKv();
    final r = repo(kv);
    await r.write(work, FolderSnapshot.absent);
    final decoded = await r.decode(kv.value, 7);
    expect(decoded.version, 7);
    expect(decoded.doc.folders.keys, ['f0123456789abcdef']);
    final deleted = await r.decode(null, 8);
    expect(deleted.access, FolderAccess.absent);
    expect(deleted.version, 8);
    expect((await r.decode('%%%', 9)).access, FolderAccess.unreadable);
  });
}
