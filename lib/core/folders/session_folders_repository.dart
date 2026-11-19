/// Reads and writes the `session-folders` KV document with compare-and-set.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

import '../api/kv_api.dart';
import '../encryption/base64.dart';
import '../models/kv.dart';
import 'session_folders_doc.dart';
import 'session_folders_envelope.dart';

/// KV key of the folder document.
const String sessionFoldersKvKey = 'session-folders';

/// A decoded document at a KV version (-1: the key was never written).
@immutable
class FolderSnapshot {
  const FolderSnapshot(this.opened, this.version);

  static const FolderSnapshot absent = FolderSnapshot(
    OpenedFolders.absent(),
    -1,
  );

  final OpenedFolders opened;
  final int version;

  FolderAccess get access => opened.access;
  FolderDoc get doc => opened.doc;
  bool get writable =>
      access == FolderAccess.ready || access == FolderAccess.absent;
}

/// Lost the compare-and-set race [SessionFoldersRepository.maxAttempts]
/// times in a row.
class FolderConflictException implements Exception {
  const FolderConflictException();

  @override
  String toString() => 'FolderConflictException';
}

class SessionFoldersRepository {
  SessionFoldersRepository({required this.kv, required this.codec});

  static const int maxAttempts = 5;

  final KvStore kv;
  final SessionFoldersCodec codec;

  Future<FolderSnapshot> load() async {
    final item = await kv.get(sessionFoldersKvKey);
    if (item == null) return FolderSnapshot.absent;
    return decode(item.value, item.version);
  }

  /// Decodes a base64 KV value; null is a deleted key at [version].
  Future<FolderSnapshot> decode(String? value, int version) async {
    if (value == null) {
      return FolderSnapshot(const OpenedFolders.absent(), version);
    }
    final Uint8List raw;
    try {
      raw = Base64Utils.decode(value);
    } on FormatException {
      return FolderSnapshot(const OpenedFolders.unreadable(), version);
    }
    return FolderSnapshot(await codec.open(raw), version);
  }

  /// Applies [edit] (null: only add missing wraps) on top of [current] and
  /// writes it, re-applying [edit] to the winner of a lost race. Returns
  /// the stored snapshot, or [current] when nothing had to be written.
  ///
  /// Throws [FolderRuleException] for a refused edit or a document this
  /// app must not overwrite, [FolderConflictException] after
  /// [maxAttempts] lost races, and KV errors as they come.
  Future<FolderSnapshot> write(FolderEdit? edit, FolderSnapshot current) async {
    var snapshot = current;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!snapshot.writable) {
        throw const FolderRuleException(FolderRule.readOnly);
      }
      final seal = snapshot.opened.seal;
      final next = edit == null ? snapshot.doc : edit.apply(snapshot.doc);
      final wrapsMissing = seal != null && codec.missingWraps(seal);
      final unchanged = identical(next, snapshot.doc);
      if (unchanged && (seal == null || !wrapsMissing)) {
        // Nothing to store: an unchanged doc, or wraps for a doc nobody
        // created yet.
        return snapshot;
      }
      final sealed = await codec.seal(next, seal);
      final response = await kv.mutate([
        KvMutation(
          key: sessionFoldersKvKey,
          version: snapshot.version,
          value: Base64Utils.encode(sealed.bytes),
        ),
      ]);
      if (response is KvMutateSuccessResponse) {
        final result = response.results
            .where((r) => r.key == sessionFoldersKvKey)
            .firstOrNull;
        return FolderSnapshot(
          OpenedFolders(
            access: FolderAccess.ready,
            doc: next,
            seal: sealed.seal,
          ),
          result?.version ?? snapshot.version + 1,
        );
      }
      final conflict = response.errors
          .where((e) => e.key == sessionFoldersKvKey)
          .firstOrNull;
      snapshot = conflict == null
          ? await load()
          : await decode(conflict.value, conflict.version);
    }
    throw const FolderConflictException();
  }
}
