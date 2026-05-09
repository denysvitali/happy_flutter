/// Stubs for the remaining CRDT-eligible domains called out in the
/// architecture overhaul (item #3).
///
/// Each domain follows the same shape as [SettingsCrdt]:
///   * [LwwMap] / OR-Set as the underlying CRDT primitive
///   * `applyRemote(patch)` for inbound merges
///   * `updateXxx(...)` returning a wire patch for outbound merges
///   * `snapshot()` exposing a plain map ready to copy into the
///     existing model classes
///
/// We deliberately keep these as one-line skeletons — the goal of
/// this commit is to establish a consistent pattern, not to flip
/// every domain over at once. The first domain (settings) is wired
/// end-to-end so reviewers can see the full integration shape.
library;

import 'lww_register.dart';

/// Profiles — small set, edits rarely conflict; LWW per profile id is
/// sufficient.
class ProfilesCrdt {
  ProfilesCrdt({required String replicaId})
      : _map = LwwMap<Map<String, Object?>?>(
          replicaId: replicaId,
          clock: () => DateTime.now().microsecondsSinceEpoch,
        );
  final LwwMap<Map<String, Object?>?> _map;
  Map<String, Map<String, Object?>?> snapshot() => {
        for (final e in _map.cells.entries) e.key: e.value.value,
      };
  Map<String, Object?> upsert(String profileId, Map<String, Object?> body) {
    _map.set(profileId, body);
    return {profileId: _map.cells[profileId]!.toJson()};
  }

  void applyRemote(Map<String, Object?> patch) {
    for (final e in patch.entries) {
      if (e.value is! Map) continue;
      final cell = LwwCell.fromJson<Map<String, Object?>?>(
          (e.value! as Map).cast<String, Object?>());
      _map.mergeCell(e.key, cell);
    }
  }
}

/// Todos — append-mostly, cross-device toggles common; needs OR-Set
/// for adds and LWW for the boolean. We model that as two LwwMaps
/// in this stub, with a bridging snapshot. A real OR-Set with
/// tombstones is the follow-up.
class TodosCrdt {
  TodosCrdt({required String replicaId})
      : _items = LwwMap<Map<String, Object?>?>(
          replicaId: replicaId,
          clock: () => DateTime.now().microsecondsSinceEpoch,
        );
  final LwwMap<Map<String, Object?>?> _items;
  Map<String, Map<String, Object?>?> snapshot() => {
        for (final e in _items.cells.entries) e.key: e.value.value,
      };
  Map<String, Object?> upsert(String id, Map<String, Object?> body) {
    _items.set(id, body);
    return {id: _items.cells[id]!.toJson()};
  }

  Map<String, Object?> delete(String id) {
    _items.set(id, null);
    return {id: _items.cells[id]!.toJson()};
  }

  void applyRemote(Map<String, Object?> patch) {
    for (final e in patch.entries) {
      if (e.value is! Map) continue;
      final cell = LwwCell.fromJson<Map<String, Object?>?>(
          (e.value! as Map).cast<String, Object?>());
      _items.mergeCell(e.key, cell);
    }
  }
}

/// Artifacts — same skeleton as todos.
class ArtifactsCrdt {
  ArtifactsCrdt({required String replicaId})
      : _items = LwwMap<Map<String, Object?>?>(
          replicaId: replicaId,
          clock: () => DateTime.now().microsecondsSinceEpoch,
        );
  final LwwMap<Map<String, Object?>?> _items;
  Map<String, Map<String, Object?>?> snapshot() => {
        for (final e in _items.cells.entries) e.key: e.value.value,
      };
  Map<String, Object?> upsert(String id, Map<String, Object?> body) {
    _items.set(id, body);
    return {id: _items.cells[id]!.toJson()};
  }

  void applyRemote(Map<String, Object?> patch) {
    for (final e in patch.entries) {
      if (e.value is! Map) continue;
      final cell = LwwCell.fromJson<Map<String, Object?>?>(
          (e.value! as Map).cast<String, Object?>());
      _items.mergeCell(e.key, cell);
    }
  }
}
