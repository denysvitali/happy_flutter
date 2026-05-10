/// Predicate returning whether [message] is something TTS should
/// speak.
typedef SpeakablePredicate = bool Function(Map<String, dynamic> message);

bool _defaultIsSpeakable(Map<String, dynamic> m) {
  if ((m['role'] as String? ?? '') != 'agent') return false;
  if ((m['kind'] as String?) != 'text') return false;
  if (m['isThinking'] == true) return false;
  return true;
}

/// Gate that decides what (if anything) the TTS engine should speak as
/// chat messages stream in.
///
/// The gate enforces three properties:
///
///  * **Speak only newly arrived agent text.** Tool calls, thinking
///    placeholders, and user messages never trigger speech.
///  * **Never speak history on entry.** When a chat is first opened,
///    the latest speakable message becomes the baseline; speech only
///    starts for messages that arrive *after* the initial load
///    completes.
///  * **One speech per logical message.** The id of the most recent
///    spoken message is tracked so repeated [evaluate] calls (cache
///    reloads, debounced sync events, content updates that don't
///    change the trailing speakable id) don't re-trigger speech.
///
/// The gate is intentionally pure — it doesn't touch
/// [TtsService] or Riverpod. Callers feed it parsed message maps and
/// the current `ttsEnabled` flag, and forward the returned text to
/// the TTS engine.
class ChatTtsGate {
  ChatTtsGate({SpeakablePredicate? isSpeakable})
    : _isSpeakable = isSpeakable ?? _defaultIsSpeakable;

  final SpeakablePredicate _isSpeakable;
  String? _lastSpokenMessageId;
  bool _initialLoadComplete = false;

  /// Whether the gate has been told the initial load is complete.
  /// Exposed for assertions/tests.
  bool get isInitialLoadComplete => _initialLoadComplete;

  /// The id of the message the gate last reported as needing speech,
  /// or the baseline id when the initial load completed.
  String? get lastSpokenMessageId => _lastSpokenMessageId;

  /// Mark the initial load as complete and seed the baseline so the
  /// next [evaluate] call doesn't replay the most recent historical
  /// agent reply.
  ///
  /// Idempotent: subsequent calls are no-ops, so it's safe to call
  /// from multiple code paths (HTTP fetch completion, cache restore,
  /// etc.).
  void markInitialLoadComplete(List<Map<String, dynamic>> messages) {
    if (_initialLoadComplete) return;
    _initialLoadComplete = true;
    _lastSpokenMessageId = _findLatestSpeakable(messages)?['id']?.toString();
  }

  /// Mark the initial load as complete using the same baseline the
  /// gate would derive on its own. Differs from
  /// [markInitialLoadComplete] only in that it accepts an iterable
  /// of dynamics — convenient for callers like
  /// `agent_conversation_screen` that hold a heterogenous `children`
  /// list.
  void markInitialLoadCompleteDynamic(Iterable<dynamic>? items) {
    final maps = <Map<String, dynamic>>[];
    if (items != null) {
      for (final item in items) {
        if (item is Map<String, dynamic>) maps.add(item);
      }
    }
    markInitialLoadComplete(maps);
  }

  /// Returns the text to speak, or `null` if nothing should be
  /// spoken.
  ///
  /// Updates internal state regardless of whether [ttsEnabled] is
  /// true: that way, toggling TTS on later doesn't cause the gate to
  /// replay the most recent message that arrived while it was off.
  String? evaluate({
    required List<Map<String, dynamic>> messages,
    required bool ttsEnabled,
  }) {
    if (!_initialLoadComplete) return null;

    final latest = _findLatestSpeakable(messages);
    if (latest == null) return null;

    final id = latest['id']?.toString();
    if (id == null || id == _lastSpokenMessageId) return null;

    _lastSpokenMessageId = id;
    if (!ttsEnabled) return null;

    final text = (latest['content'] ?? latest['text'] ?? '').toString();
    return text.isEmpty ? null : text;
  }

  /// Variant of [evaluate] that accepts an iterable of dynamics.
  /// Convenience for callers whose underlying list is `List<dynamic>`
  /// (e.g. `taskMsg['children']`).
  String? evaluateDynamic({
    required Iterable<dynamic>? items,
    required bool ttsEnabled,
  }) {
    final maps = <Map<String, dynamic>>[];
    if (items != null) {
      for (final item in items) {
        if (item is Map<String, dynamic>) maps.add(item);
      }
    }
    return evaluate(messages: maps, ttsEnabled: ttsEnabled);
  }

  /// Reset the gate. Intended for use when the underlying conversation
  /// changes (e.g. switching sessions on a reused widget).
  void reset() {
    _lastSpokenMessageId = null;
    _initialLoadComplete = false;
  }

  /// Record that the caller just spoke message [messageId] outside
  /// the normal [evaluate] flow (for example, the user tapped
  /// prev/next on the playback bar). Updating the baseline here
  /// prevents the next live message from being treated as a fresh
  /// reply and re-spoken.
  void recordSpoken(String? messageId) {
    if (messageId == null) return;
    _initialLoadComplete = true;
    _lastSpokenMessageId = messageId;
  }

  /// Walks the list from the tail forward, returning the most recent
  /// speakable message according to [_isSpeakable], or `null` if none
  /// exists.
  ///
  /// The default predicate excludes thinking placeholders (which
  /// carry the literal string `*Thinking...*` rather than the
  /// assistant's actual reply), tool calls, and user messages.
  Map<String, dynamic>? _findLatestSpeakable(
    List<Map<String, dynamic>> messages,
  ) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (_isSpeakable(m)) return m;
    }
    return null;
  }
}
