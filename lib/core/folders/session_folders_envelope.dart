/// Encrypted envelope of the `session-folders` KV value.
///
/// ```json
/// {"v":1,"keys":{"account":"…","legacy":"…","machines":{"<id>":"…"}},
///  "data":"…"}
/// ```
///
/// A random 32-byte folder key (FK) encrypts `data` (AES-256-GCM data-key
/// JSON) and is wrapped once per reader: `account` like a session
/// dataEncryptionKey, `legacy` as secretbox JSON `{"k":b64}` under the
/// master secret, and one AES-GCM `{"k":b64}` per data-key machine.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, mapEquals;

import '../encryption/base64.dart';
import '../encryption/encryption_manager.dart';
import '../encryption/encryptor.dart';
import 'session_folders_doc.dart';

/// The account keys an app holds; wraps FK for each reader.
abstract interface class FolderKeyring {
  /// Opens `0x00 ‖ box` sealed to the content public key.
  Future<Uint8List?> openBox(Uint8List wrapped);
  Future<Uint8List> sealBox(Uint8List key);

  /// Legacy secretbox of a JSON value under the master secret.
  Future<Object?> openLegacy(Uint8List sealed);
  Future<Uint8List> sealLegacy(Object json);

  /// Unwrapped data keys of the data-key machines this app can open.
  Map<String, Uint8List> get machineKeys;
}

/// [FolderKeyring] over the signed-in account's [Encryption].
class EncryptionFolderKeyring implements FolderKeyring {
  EncryptionFolderKeyring(this._encryption, this._machineKeys);

  final Encryption _encryption;
  final Map<String, Uint8List> Function() _machineKeys;

  @override
  Future<Uint8List?> openBox(Uint8List wrapped) =>
      _encryption.decryptEncryptionKey(Base64Utils.encode(wrapped));

  @override
  Future<Uint8List> sealBox(Uint8List key) =>
      _encryption.encryptEncryptionKey(key);

  @override
  Future<Object?> openLegacy(Uint8List sealed) async =>
      (await SecretBoxEncryption(
        _encryption.legacySecretKey,
      ).decrypt([sealed])).first;

  @override
  Future<Uint8List> sealLegacy(Object json) async => (await SecretBoxEncryption(
    _encryption.legacySecretKey,
  ).encrypt([json])).first;

  @override
  Map<String, Uint8List> get machineKeys => _machineKeys();
}

/// How far this app can use the stored document.
enum FolderAccess {
  /// No document yet; the first edit creates it.
  absent,

  /// Readable and writable.
  ready,

  /// Written by a newer client (higher `v`): shown, never written.
  readOnly,

  /// Cannot be decoded or decrypted: no folders shown, never overwritten.
  unreadable,
}

/// The wraps and FK of an opened envelope, reused when resealing.
@immutable
class FolderSeal {
  const FolderSeal({
    required this.folderKey,
    this.account,
    this.legacy,
    this.machines = const {},
  });

  final Uint8List folderKey;
  final String? account;
  final String? legacy;
  final Map<String, String> machines;

  @override
  bool operator ==(Object other) =>
      other is FolderSeal &&
      other.account == account &&
      other.legacy == legacy &&
      mapEquals(other.machines, machines);

  @override
  int get hashCode => Object.hash(
    account,
    legacy,
    Object.hashAllUnordered(machines.entries.map((e) => (e.key, e.value))),
  );
}

/// One decoded KV value.
@immutable
class OpenedFolders {
  const OpenedFolders({
    required this.access,
    this.doc = FolderDoc.empty,
    this.seal,
  });

  const OpenedFolders.absent() : this(access: FolderAccess.absent);
  const OpenedFolders.unreadable() : this(access: FolderAccess.unreadable);

  final FolderAccess access;
  final FolderDoc doc;
  final FolderSeal? seal;
}

final Random _random = Random.secure();

Uint8List _randomKey() =>
    Uint8List.fromList(List<int>.generate(32, (_) => _random.nextInt(256)));

class SessionFoldersCodec {
  const SessionFoldersCodec(this.keyring);

  final FolderKeyring keyring;

  /// Decodes a stored value (raw UTF-8 JSON bytes). Never throws.
  Future<OpenedFolders> open(Uint8List raw) async {
    try {
      final env = jsonDecode(utf8.decode(raw));
      if (env is! Map) return const OpenedFolders.unreadable();
      final v = env['v'];
      if (v is! int || v < sessionFoldersVersion) {
        return const OpenedFolders.unreadable();
      }
      final keys = env['keys'];
      final data = env['data'];
      if (keys is! Map || data is! String) {
        return const OpenedFolders.unreadable();
      }
      final account = _string(keys['account']);
      final legacy = _string(keys['legacy']);
      final machines = <String, String>{};
      final rawMachines = keys['machines'];
      if (rawMachines is Map) {
        for (final e in rawMachines.entries) {
          if (e.key is String && e.value is String) {
            machines[e.key as String] = e.value as String;
          }
        }
      }
      final fk = await _openFolderKey(account, legacy, machines);
      if (fk == null) return const OpenedFolders.unreadable();
      final plain = (await AES256Encryption(
        fk,
      ).decrypt([Base64Utils.decode(data)])).first;
      if (plain is! Map) return const OpenedFolders.unreadable();
      return OpenedFolders(
        access: v > sessionFoldersVersion
            ? FolderAccess.readOnly
            : FolderAccess.ready,
        doc: FolderDoc.fromJson(plain),
        seal: FolderSeal(
          folderKey: fk,
          account: account,
          legacy: legacy,
          machines: machines,
        ),
      );
    } on Object {
      return const OpenedFolders.unreadable();
    }
  }

  Future<Uint8List?> _openFolderKey(
    String? account,
    String? legacy,
    Map<String, String> machines,
  ) async {
    if (account != null) {
      final fk = await _guard(
        () => keyring.openBox(Base64Utils.decode(account)),
      );
      if (fk != null && fk.length == 32) return fk;
    }
    if (legacy != null) {
      final fk = _unwrapJson(
        await _guard(() => keyring.openLegacy(Base64Utils.decode(legacy))),
      );
      if (fk != null) return fk;
    }
    for (final MapEntry(:key, :value) in keyring.machineKeys.entries) {
      final wrap = machines[key];
      if (wrap == null) continue;
      final fk = _unwrapJson(
        await _guard(
          () async => (await AES256Encryption(
            value,
          ).decrypt([Base64Utils.decode(wrap)])).first,
        ),
      );
      if (fk != null) return fk;
    }
    return null;
  }

  /// Whether resealing [seal] would add a wrap this app can produce.
  bool missingWraps(FolderSeal seal) =>
      seal.account == null ||
      seal.legacy == null ||
      keyring.machineKeys.keys.any((id) => !seal.machines.containsKey(id));

  /// Encrypts [doc] as UTF-8 JSON bytes, reusing [seal]'s key and wraps
  /// (a null [seal] creates a new key) and adding every missing wrap.
  Future<({Uint8List bytes, FolderSeal seal})> seal(
    FolderDoc doc,
    FolderSeal? seal,
  ) async {
    final fk = seal?.folderKey ?? _randomKey();
    final wrap = {'k': Base64Utils.encode(fk)};
    final account =
        seal?.account ?? Base64Utils.encode(await keyring.sealBox(fk));
    final legacy =
        seal?.legacy ?? Base64Utils.encode(await keyring.sealLegacy(wrap));
    final machines = <String, String>{...?seal?.machines};
    for (final MapEntry(:key, :value) in keyring.machineKeys.entries) {
      if (machines.containsKey(key)) continue;
      machines[key] = Base64Utils.encode(
        (await AES256Encryption(value).encrypt([wrap])).first,
      );
    }
    final data = (await AES256Encryption(fk).encrypt([doc.toJson()])).first;
    final env = {
      'v': sessionFoldersVersion,
      'keys': {
        'account': account,
        'legacy': legacy,
        if (machines.isNotEmpty) 'machines': machines,
      },
      'data': Base64Utils.encode(data),
    };
    return (
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(env))),
      seal: FolderSeal(
        folderKey: fk,
        account: account,
        legacy: legacy,
        machines: machines,
      ),
    );
  }
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Uint8List? _unwrapJson(Object? json) {
  if (json is! Map) return null;
  final k = json['k'];
  if (k is! String) return null;
  try {
    final key = Base64Utils.decode(k);
    return key.length == 32 ? key : null;
  } on FormatException {
    return null;
  }
}

Future<T?> _guard<T>(Future<T?> Function() body) async {
  try {
    return await body();
  } on Object {
    return null;
  }
}
