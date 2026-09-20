import 'dart:collection';

import '../utils/utf16_sanitizer.dart';

/// Transient previews live outside the durable message window and its cache.
/// Full snapshots tolerate packet loss; monotonically growing text rejects
/// reordered snapshots. A durable completion always wins, including replay.
class MessageStreamStore {
  final _previews = <String, Map<String, dynamic>>{};
  final _updatedAt = <String, int>{};
  final _completed = LinkedHashSet<String>();

  bool get isEmpty => _previews.isEmpty;

  bool accept(dynamic envelope, {required int nowMs}) {
    if (envelope is! Map || envelope['role'] != 'agent') return false;
    final content = envelope['content'];
    if (content is! Map || content['type'] != 'codex') return false;
    final data = content['data'];
    if (data is! Map || data['type'] != 'model-output') return false;
    final id = data['streamId'];
    final text = data['fullText'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        text is! String ||
        text.isEmpty ||
        text.length > 256 * 1024 ||
        data['isStreaming'] != true ||
        _completed.contains(id)) {
      return false;
    }
    final previous = _previews[id];
    if (previous == null && _previews.length >= 32) return false;
    if (previous != null &&
        (previous['content'] as String).length >= text.length) {
      return false;
    }
    _previews[id] = {
      'id': 'stream:$id',
      'streamId': id,
      'localId': null,
      'role': 'agent',
      'kind': 'text',
      'content': sanitizeUtf16(text),
      'createdAt': previous?['createdAt'] ?? nowMs,
      'isStreaming': true,
    };
    _updatedAt[id] = nowMs;
    return true;
  }

  List<Map<String, dynamic>> merge(List<Map<String, dynamic>> durable) {
    for (final row in durable) {
      final id = row['streamId'];
      if (id is! String || row['role'] != 'agent') continue;
      _previews.remove(id);
      _updatedAt.remove(id);
      _completed.add(id);
    }
    while (_completed.length > 256) {
      _completed.remove(_completed.first);
    }
    return [...durable, ..._previews.values];
  }

  bool expire(int nowMs) {
    final expired = _updatedAt.entries
        .where((entry) => nowMs - entry.value >= 120000)
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      _updatedAt.remove(id);
      _previews.remove(id);
    }
    return expired.isNotEmpty;
  }
}
