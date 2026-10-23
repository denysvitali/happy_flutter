import 'dart:collection';

/// Immutable single-entry patch over an immutable session-keyed snapshot.
/// Periodic compaction bounds lookup depth without copying on every update.
class SessionMapPatch<V> extends MapBase<String, V> {
  SessionMapPatch(
    Map<String, V> previous,
    this._key,
    this._value, {
    required bool remove,
  }) : _remove = remove,
       _previous = previous is SessionMapPatch<V> && previous._depth >= 16
           ? Map<String, V>.unmodifiable(previous)
           : previous {
    _depth = switch (_previous) {
      final SessionMapPatch<V> chain => chain._depth + 1,
      _ => 1,
    };
  }

  final Map<String, V> _previous;
  final String _key;
  final V? _value;
  final bool _remove;
  late final int _depth;

  @override
  V? operator [](Object? key) => key == _key ? _value : _previous[key];

  @override
  bool containsKey(Object? key) =>
      key == _key ? !_remove : _previous.containsKey(key);

  @override
  int get length =>
      _previous.length +
      (_previous.containsKey(_key) ? 0 : 1) -
      (_remove ? 1 : 0);

  @override
  Iterable<String> get keys sync* {
    for (final key in _previous.keys) {
      if (key != _key || !_remove) yield key;
    }
    if (!_remove && !_previous.containsKey(_key)) yield _key;
  }

  @override
  void operator []=(String key, V value) =>
      throw UnsupportedError('Immutable session map');

  @override
  V? remove(Object? key) => throw UnsupportedError('Immutable session map');

  @override
  void clear() => throw UnsupportedError('Immutable session map');
}
