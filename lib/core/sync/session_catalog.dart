import 'dart:collection';

import '../models/session.dart';

/// Tracks catalog writes for independent UI consumers without changing their
/// session/message identity. Late readers and replacements require a full read.
class SessionCatalog extends MapBase<String, Session> {
  final Map<String, Session> _values = {};
  final List<String?> _changes = List.filled(1024, null);
  int _revision = 0;
  int _resetRevision = 0;

  int get revision => _revision;

  Set<String>? changesSince(int revision) {
    if (revision < _resetRevision ||
        revision > _revision ||
        _revision - revision > _changes.length) {
      return null;
    }
    return {
      for (var r = revision + 1; r <= _revision; r++)
        _changes[r % _changes.length]!,
    };
  }

  void _record(String key) {
    _revision++;
    _changes[_revision % _changes.length] = key;
  }

  void replaceAll(Map<String, Session> values) {
    // Snapshot before clearing in case the caller supplied a live view.
    final replacement = Map<String, Session>.of(values);
    _values
      ..clear()
      ..addAll(replacement);
    _resetRevision = ++_revision;
    _changes.fillRange(0, _changes.length, null);
  }

  @override
  Session? operator [](Object? key) => _values[key];

  @override
  void operator []=(String key, Session value) {
    if (identical(_values[key], value)) return;
    _values[key] = value;
    _record(key);
  }

  @override
  Session? remove(Object? key) {
    final previous = _values.remove(key);
    if (previous != null) _record(key as String);
    return previous;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _resetRevision = ++_revision;
    _changes.fillRange(0, _changes.length, null);
  }

  @override
  int get length => _values.length;

  @override
  bool containsKey(Object? key) => _values.containsKey(key);

  @override
  Iterable<String> get keys => _values.keys;
}
