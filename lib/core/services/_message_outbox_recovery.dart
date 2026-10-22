part of 'message_outbox.dart';

/// Count-only review ticket. No legacy text, paths, or other session IDs leave
/// the outbox. A ticket is valid only for the runtime and bytes reviewed.
class LegacyOutboxPreview {
  LegacyOutboxPreview._(
    this._outbox,
    this._generation,
    this._owner,
    this._sessionId,
    this._digest,
    this.count,
    this._isCurrent,
  );

  final MessageOutbox _outbox;
  final int _generation;
  final String _owner;
  final String _sessionId;
  final Digest _digest;
  final bool Function() _isCurrent;
  final int count;
}

extension LegacyOutboxRecovery on MessageOutbox {
  bool hasOwnerScope(String owner) =>
      owner != 'unowned' && owner == _ownerScope;

  bool _canRecover(LegacyOutboxPreview preview) =>
      identical(preview._outbox, this) &&
      preview._generation == _generation &&
      preview._owner == _ownerScope &&
      _ownerScope != 'unowned' &&
      !_suspended &&
      preview._isCurrent();

  Map<String, dynamic> _recoveryBuckets(String raw) {
    final plaintext = _protection.isProtected(raw)
        ? _protection.unprotectString(
            raw,
            associatedData: MessageOutbox._outboxAssociatedData,
          )
        : raw;
    if (plaintext == null) throw const FormatException('Unavailable outbox');
    return _decodeBuckets(plaintext);
  }

  List<OutboxEntry> _legacyForSession(
    Map<String, dynamic> buckets,
    String sessionId,
  ) {
    final legacy = buckets['unowned'] as List<dynamic>? ?? [];
    final entries = legacy
        .map((item) => OutboxEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    final ids = <String>{};
    for (final entry in entries) {
      if (entry.localId.isEmpty ||
          entry.sessionId.isEmpty ||
          !ids.add(entry.localId)) {
        throw const FormatException('Invalid legacy identity');
      }
    }
    return entries.where((entry) => entry.sessionId == sessionId).toList();
  }

  /// Read-only, count-only preview for a session already verified by the caller
  /// against the current account/server. [isCurrent] must fence that runtime
  /// and session after every await; it must not perform IO or mutate state.
  Future<LegacyOutboxPreview?> previewLegacyRecovery({
    required String sessionId,
    required bool Function() isCurrent,
  }) async {
    final generation = _generation;
    final owner = _ownerScope;
    bool current() =>
        generation == _generation &&
        owner == _ownerScope &&
        owner != 'unowned' &&
        !_suspended &&
        isCurrent();
    if (!current() || sessionId.isEmpty) return null;
    try {
      await _storageTail;
      if (!current()) return null;
      if (!_protection.isReady) await _protection.initialize();
      if (!current()) return null;
      final raw = await _storage.getOutboxEntries();
      if (!current() || raw == null) return null;
      final entries = _legacyForSession(_recoveryBuckets(raw), sessionId);
      if (entries.isEmpty) return null;
      return LegacyOutboxPreview._(
        this,
        generation,
        owner,
        sessionId,
        sha256.convert(utf8.encode(raw)),
        entries.length,
        isCurrent,
      );
    } catch (_) {
      // Never log payloads or rewrite undecodable bytes.
      return null;
    }
  }

  /// Explicitly confirmed transfer only. Recovered entries are permanent dead
  /// letters: neither this operation nor restart/reconnect sends them. The user
  /// must separately Retry in the original conversation.
  Future<bool> recoverLegacy(LegacyOutboxPreview preview) {
    final result = Completer<bool>();
    _storageTail = _storageTail.then((_) async {
      try {
        if (!_canRecover(preview)) {
          result.complete(false);
          return;
        }
        final raw = await _storage.getOutboxEntries();
        if (!_canRecover(preview) ||
            raw == null ||
            sha256.convert(utf8.encode(raw)) != preview._digest) {
          result.complete(false);
          return;
        }
        final buckets = _recoveryBuckets(raw);
        final selected = _legacyForSession(buckets, preview._sessionId);
        final owned = (buckets[_ownerScope] as List<dynamic>? ?? [])
            .map((item) => OutboxEntry.fromJson(item as Map<String, dynamic>))
            .toList();
        final ids = {
          ...owned.map((entry) => entry.localId),
          ..._entries.keys,
          ..._dead.keys,
        };
        if (selected.length != preview.count ||
            owned.any(
              (entry) =>
                  !_entries.containsKey(entry.localId) &&
                  !_dead.containsKey(entry.localId),
            ) ||
            selected.any((entry) => ids.contains(entry.localId))) {
          result.complete(false);
          return;
        }
        final recovered = selected
            .map(
              (entry) => entry.copyWith(
                dead: true,
                failureClass: OutboxFailureClass.permanent,
                failureReason: 'legacy_recovered',
              ),
            )
            .toList();
        final remaining = (buckets['unowned'] as List<dynamic>)
            .where((dynamic item) => item['sessionId'] != preview._sessionId)
            .toList();
        buckets['unowned'] = remaining;
        buckets[_ownerScope] = [
          ...owned.map((entry) => entry.toJson()),
          ...recovered.map((entry) => entry.toJson()),
        ];
        final protected = _protection.protectString(
          jsonEncode({'version': 2, 'buckets': buckets}),
          associatedData: MessageOutbox._outboxAssociatedData,
        );
        if (protected == null || !_canRecover(preview)) {
          result.complete(false);
          return;
        }
        // One atomic shared-envelope write; all other persists drain this lane.
        final reserved = selected.map((entry) => entry.localId).toSet();
        _legacyRecoveryIds.addAll(reserved);
        try {
          await _storage.saveOutboxEntries(protected);
        } finally {
          if (preview._generation == _generation) {
            _legacyRecoveryIds.removeAll(reserved);
          }
        }
        if (!_canRecover(preview)) {
          result.complete(false);
          return;
        }
        for (final entry in recovered) {
          _dead[entry.localId] = entry;
        }
        _unownedEntryCount = remaining.length;
        result.complete(true);
      } catch (_) {
        result.complete(false);
      }
    });
    return result.future;
  }
}
