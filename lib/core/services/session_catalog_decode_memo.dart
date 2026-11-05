import 'dart:async';

import '../models/session.dart';
import '../models/todo.dart';
import 'main_isolate_stall_tracker.dart';

/// Rows per slice of catalog decode work. One row costs a base64 decode, two
/// native AES-GCM decrypts, two JSON decodes and a model parse; sixteen keep
/// a slice to a few milliseconds on a mid-range phone.
const int catalogDecodeBatchSize = 16;

/// Run [task] over [items] in slices of [batchSize], yielding to the event
/// loop between slices so a frame can render.
///
/// `Future.wait` over a whole catalog does not yield: the native decrypt is
/// synchronous, so every task's body ran back to back in one microtask
/// chain. Each slice is recorded under [name] in
/// [MainIsolateStallTracker], so a slice that still stalls a frame is
/// attributed instead of reported as `untracked`. Results keep input order.
/// Returns `null` without starting further slices once [isStale] is true
/// (a runtime/account change after a yield).
Future<List<R>?> runInYieldingBatches<T, R>(
  List<T> items,
  Future<R> Function(T item) task, {
  required String name,
  required bool Function() isStale,
  int batchSize = catalogDecodeBatchSize,
}) async {
  final results = <R>[];
  final tracker = MainIsolateStallTracker.instance;
  for (var start = 0; start < items.length; start += batchSize) {
    if (start > 0) {
      await Future<void>.delayed(Duration.zero);
      if (isStale()) return null;
    }
    final end = start + batchSize < items.length
        ? start + batchSize
        : items.length;
    final sliceStart = tracker.now();
    final slice = await Future.wait([
      for (var i = start; i < end; i++) task(items[i]),
    ]);
    tracker.record(name, sliceStart, tracker.now());
    results.addAll(slice);
  }
  return results;
}

/// Identity of one encrypted catalog blob: the decryptor that opened it, its
/// server version and a fingerprint of the ciphertext.
///
/// The fingerprint is the ciphertext's length plus `String.hashCode` rather
/// than the string itself, so the memo does not pin megabytes of base64 for a
/// large catalog. A false hit needs the same session, decryptor and version
/// with a different ciphertext of equal length and hash; any version bump or
/// key rotation (a new decryptor) misses.
typedef CatalogBlobKey = ({
  Object decryptor,
  int version,
  int length,
  int hash,
});

/// Builds the [CatalogBlobKey] for [cipher] opened by [decryptor].
CatalogBlobKey catalogBlobKey(Object decryptor, int version, String? cipher) {
  final text = cipher ?? '';
  return (
    decryptor: decryptor,
    version: version,
    length: text.length,
    hash: text.hashCode,
  );
}

bool _sameBlob(CatalogBlobKey a, CatalogBlobKey b) =>
    identical(a.decryptor, b.decryptor) &&
    a.version == b.version &&
    a.length == b.length &&
    a.hash == b.hash;

/// Parsed metadata of a catalog row, as produced by the full decode path.
typedef CatalogMetadataDecode = ({Metadata? metadata, List<TodoItem>? todos});

/// Remembers how each session's encrypted `metadata` / `agentState` decoded
/// in the last catalog read so an unchanged row is not decrypted, JSON
/// decoded and parsed again.
///
/// Production evidence (build 319000, 1,258 sessions): every full catalog
/// read re-decrypted all 2,516 blobs on the UI isolate because the shared
/// [EncryptionCache] holds 1,000 entries per kind, so a sequential scan of a
/// larger catalog evicts every entry before it is reused. The burst ran as
/// one microtask chain and froze chat/home for ~550 ms (frame blocker
/// `native_core.decrypt_sync` or `untracked`).
///
/// Only successful decodes are remembered, so a failed decrypt is retried
/// on the next read exactly as before. Entries are runtime-scoped: callers
/// clear the memo on shutdown/account reset.
class SessionCatalogDecodeMemo {
  final Map<String, (CatalogBlobKey, CatalogMetadataDecode)> _metadata = {};
  final Map<String, (CatalogBlobKey, AgentState?)> _agentState = {};

  int get metadataCount => _metadata.length;
  int get agentStateCount => _agentState.length;

  CatalogMetadataDecode? metadata(String sessionId, CatalogBlobKey key) {
    final entry = _metadata[sessionId];
    if (entry == null || !_sameBlob(entry.$1, key)) return null;
    return entry.$2;
  }

  /// The memoized agent state, or `null` on a miss. A hit may itself carry
  /// a `null` [AgentState] (an empty or unparseable blob), so this returns a
  /// record to keep "miss" distinct from "decoded to nothing".
  ({AgentState? value})? agentState(String sessionId, CatalogBlobKey key) {
    final entry = _agentState[sessionId];
    if (entry == null || !_sameBlob(entry.$1, key)) return null;
    return (value: entry.$2);
  }

  void putMetadata(
    String sessionId,
    CatalogBlobKey key,
    CatalogMetadataDecode decoded,
  ) => _metadata[sessionId] = (key, decoded);

  void putAgentState(String sessionId, CatalogBlobKey key, AgentState? value) =>
      _agentState[sessionId] = (key, value);

  /// Point the memo at the resident row's parsed objects when that row was
  /// kept because it equals the freshly decoded one. The next read then
  /// compares by identity instead of deep equality.
  void adopt(Session resident) {
    final meta = _metadata[resident.id];
    if (meta != null && meta.$1.version == resident.metadataVersion) {
      _metadata[resident.id] = (
        meta.$1,
        (metadata: resident.metadata, todos: resident.todos),
      );
    }
    final agent = _agentState[resident.id];
    if (agent != null && agent.$1.version == resident.agentStateVersion) {
      _agentState[resident.id] = (agent.$1, resident.agentState);
    }
  }

  /// Drop sessions a complete catalog read no longer returned.
  void retainOnly(Set<String> sessionIds) {
    _metadata.removeWhere((id, _) => !sessionIds.contains(id));
    _agentState.removeWhere((id, _) => !sessionIds.contains(id));
  }

  void clear() {
    _metadata.clear();
    _agentState.clear();
  }
}
