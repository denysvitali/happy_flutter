part of 'sync_service.dart';

extension SyncMessageStream on Sync {
  Future<void> _handleMessageStream(Map<String, dynamic> payload) async {
    final sid = payload['id'];
    final encrypted = payload['message'];
    if (!isInitialized ||
        sid is! String ||
        sid != _visibleSessionId ||
        encrypted is! String ||
        encrypted.length > 3 * 1024 * 1024 ||
        _messageStreamDecryptions >= 4) {
      return;
    }
    final cipher = encryption.getSessionEncryption(sid);
    if (cipher == null) return;
    final runtime = _runtimeGeneration;
    final generation = _messageStreamGeneration;
    _messageStreamDecryptions++;
    try {
      final envelope = await cipher.decryptRaw(encrypted);
      if (runtime != _runtimeGeneration ||
          generation != _messageStreamGeneration ||
          !isInitialized ||
          sid != _visibleSessionId ||
          InvalidateSync.isBackgrounded) {
        return;
      }
      final store = _messageStreams.putIfAbsent(sid, MessageStreamStore.new);
      store.merge(_sessionMessages[sid] ?? const []);
      if (!store.accept(
        envelope,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      )) {
        return;
      }
      _notifyMessageStreamChanged(sid);
      _messageStreamExpiry ??= Timer.periodic(const Duration(seconds: 15), (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final entry in _messageStreams.entries) {
          if (entry.value.expire(now)) _notifyMessageStreamChanged(entry.key);
        }
        if (_messageStreams.values.every((store) => store.isEmpty)) {
          _messageStreamExpiry?.cancel();
          _messageStreamExpiry = null;
        }
      });
    } catch (error, stack) {
      logger.warning('Message preview could not be decoded', error, stack);
    } finally {
      if (generation == _messageStreamGeneration) {
        _messageStreamDecryptions--;
      }
    }
  }

  void _notifyMessageStreamChanged(String sid) {
    // No mutation generation or disk write: previews are a view overlay.
    _sessionMessagesViewCache.remove(sid);
    _bumpMessagesRevision(sid);
    _notifySessionMessagesChangedUiOnly(sid);
  }

  void _clearMessageStreams() {
    _messageStreamGeneration++;
    _messageStreamDecryptions = 0;
    for (final sid in _messageStreams.keys) {
      _sessionMessagesViewCache.remove(sid);
    }
    _messageStreams.clear();
    _messageStreamExpiry?.cancel();
    _messageStreamExpiry = null;
  }
}
