/// Last-Writer-Wins register, the workhorse CRDT for the settings
/// domain (item #3 of the architecture overhaul).
///
/// Each cell carries a [(timestamp, replicaId)] tag; merge picks the
/// cell with the larger timestamp, breaking ties on replicaId so the
/// merge is commutative, associative, and idempotent.
///
/// Unlike a vanilla TLA+ LWW, we deliberately use *Lamport-like*
/// timestamps minted by the local replica — the invariant we care
/// about is convergence, not strict real-time ordering. Callers feed
/// in their own clock; tests use a deterministic counter.
library;

import 'package:meta/meta.dart';

@immutable
class LwwTag implements Comparable<LwwTag> {
  const LwwTag({required this.timestamp, required this.replicaId});
  final int timestamp;
  final String replicaId;

  @override
  int compareTo(LwwTag other) {
    final byTs = timestamp.compareTo(other.timestamp);
    if (byTs != 0) return byTs;
    return replicaId.compareTo(other.replicaId);
  }

  @override
  bool operator ==(Object other) =>
      other is LwwTag &&
      other.timestamp == timestamp &&
      other.replicaId == replicaId;

  @override
  int get hashCode => Object.hash(timestamp, replicaId);

  Map<String, Object?> toJson() =>
      {'timestamp': timestamp, 'replicaId': replicaId};

  static LwwTag fromJson(Map<String, Object?> json) => LwwTag(
        timestamp: json['timestamp']! as int,
        replicaId: json['replicaId']! as String,
      );
}

@immutable
class LwwCell<T> {
  const LwwCell({required this.value, required this.tag});
  final T? value;
  final LwwTag tag;

  Map<String, Object?> toJson() => {
        'value': value,
        'tag': tag.toJson(),
      };

  static LwwCell<T> fromJson<T>(Map<String, Object?> json) => LwwCell<T>(
        value: json['value'] as T?,
        tag: LwwTag.fromJson(
            (json['tag']! as Map).cast<String, Object?>()),
      );
}

/// A keyed LWW map. Merging two maps is a per-key max over [LwwTag]s.
class LwwMap<T> {
  LwwMap({required this.replicaId, required int Function() clock})
      : _clock = clock,
        _cells = <String, LwwCell<T>>{};

  LwwMap._copy({
    required this.replicaId,
    required int Function() clock,
    required Map<String, LwwCell<T>> cells,
  })  : _clock = clock,
        _cells = Map.of(cells);

  final String replicaId;
  final int Function() _clock;
  final Map<String, LwwCell<T>> _cells;

  Map<String, LwwCell<T>> get cells => Map.unmodifiable(_cells);

  T? get(String key) => _cells[key]?.value;

  /// Sets [key] to [value] using the local clock + replicaId. Returns
  /// the new tag so callers can ship it on the wire.
  LwwTag set(String key, T? value) {
    final tag = LwwTag(timestamp: _clock(), replicaId: replicaId);
    _cells[key] = LwwCell<T>(value: value, tag: tag);
    return tag;
  }

  /// Merges [other] into this map. Pure: no clock advance.
  void merge(LwwMap<T> other) {
    for (final entry in other._cells.entries) {
      final mine = _cells[entry.key];
      if (mine == null || entry.value.tag.compareTo(mine.tag) > 0) {
        _cells[entry.key] = entry.value;
      }
    }
  }

  /// Merges a single remote cell — used when applying a wire update.
  void mergeCell(String key, LwwCell<T> incoming) {
    final mine = _cells[key];
    if (mine == null || incoming.tag.compareTo(mine.tag) > 0) {
      _cells[key] = incoming;
    }
  }

  Map<String, Object?> toJson() => {
        for (final entry in _cells.entries)
          entry.key: entry.value.toJson(),
      };

  /// Reconstitutes a map from a snapshot. Useful for restoring from
  /// MMKV. Caller supplies replicaId and clock anew.
  static LwwMap<T> fromJson<T>(
    Map<String, Object?> json, {
    required String replicaId,
    required int Function() clock,
  }) {
    final map = LwwMap<T>(replicaId: replicaId, clock: clock);
    for (final entry in json.entries) {
      final raw = (entry.value! as Map).cast<String, Object?>();
      map._cells[entry.key] = LwwCell.fromJson<T>(raw);
    }
    return map;
  }

  @visibleForTesting
  LwwMap<T> copy() =>
      LwwMap<T>._copy(replicaId: replicaId, clock: _clock, cells: _cells);
}
