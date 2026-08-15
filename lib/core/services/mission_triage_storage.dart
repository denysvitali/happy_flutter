import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mmkv_storage.dart';

/// Device-local Mission Control triage decisions.
///
/// Pins, snoozes, and workspace mutes are single-device conveniences, so
/// they live in MMKV rather than the synced Settings object.
@immutable
class MissionTriageState {
  const MissionTriageState({
    this.pinnedSessions = const {},
    this.snoozedUntil = const {},
    this.mutedFolders = const {},
  });

  final Set<String> pinnedSessions;
  final Map<String, int> snoozedUntil;
  final Set<String> mutedFolders;

  bool isPinned(String sessionId) => pinnedSessions.contains(sessionId);

  bool isSnoozed(String sessionId, {int? nowMs}) {
    final until = snoozedUntil[sessionId];
    if (until == null) return false;
    return until > (nowMs ?? DateTime.now().millisecondsSinceEpoch);
  }

  bool isMuted(String folderKey) => mutedFolders.contains(folderKey);

  @override
  bool operator ==(Object other) =>
      other is MissionTriageState &&
          setEquals(pinnedSessions, other.pinnedSessions) &&
          mapEquals(snoozedUntil, other.snoozedUntil) &&
          setEquals(mutedFolders, other.mutedFolders);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(pinnedSessions),
    Object.hashAll(
      snoozedUntil.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(mutedFolders),
  );
}

/// Riverpod notifier persisting [MissionTriageState] to MMKV.
class MissionTriageNotifier extends Notifier<MissionTriageState> {
  MissionTriageNotifier({MMKVStorage? storage})
      : _storage = storage ?? MMKVStorage();

  static const _storageKey = 'mission-control-triage';

  /// Default snooze window used by the Mission Control row menu.
  static const snoozeDuration = Duration(hours: 1);

  final MMKVStorage _storage;

  @override
  MissionTriageState build() {
    final raw = _storage.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const MissionTriageState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const MissionTriageState();
      final snoozed = <String, int>{};
      final snoozedJson = decoded['s'];
      if (snoozedJson is Map) {
        for (final entry in snoozedJson.entries) {
          final value = entry.value;
          if (value is int && value > 0) {
            snoozed[entry.key.toString()] = value;
          }
        }
      }
      return MissionTriageState(
        pinnedSessions: {
          if (decoded['p'] is List)
            for (final id in decoded['p'].whereType<String>()) id,
        },
        snoozedUntil: snoozed,
        mutedFolders: {
          if (decoded['m'] is List)
            for (final key in decoded['m'].whereType<String>()) key,
        },
      );
    } catch (_) {
      // Corrupt payload — reset rather than crash the dashboard.
      return const MissionTriageState();
    }
  }

  void togglePin(String sessionId) {
    final pinned = Set<String>.from(state.pinnedSessions);
    if (!pinned.remove(sessionId)) pinned.add(sessionId);
    _commit(
      MissionTriageState(
        pinnedSessions: pinned,
        snoozedUntil: state.snoozedUntil,
        mutedFolders: state.mutedFolders,
      ),
    );
  }

  void snooze(String sessionId, [Duration duration = snoozeDuration]) {
    final snoozed = Map<String, int>.from(state.snoozedUntil);
    snoozed[sessionId] =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    _commit(
      MissionTriageState(
        pinnedSessions: state.pinnedSessions,
        snoozedUntil: snoozed,
        mutedFolders: state.mutedFolders,
      ),
    );
  }

  void unsnooze(String sessionId) {
    final snoozed = Map<String, int>.from(state.snoozedUntil)..remove(
      sessionId,
    );
    _commit(
      MissionTriageState(
        pinnedSessions: state.pinnedSessions,
        snoozedUntil: snoozed,
        mutedFolders: state.mutedFolders,
      ),
    );
  }

  void toggleMute(String folderKey) {
    final muted = Set<String>.from(state.mutedFolders);
    if (!muted.remove(folderKey)) muted.add(folderKey);
    _commit(
      MissionTriageState(
        pinnedSessions: state.pinnedSessions,
        snoozedUntil: state.snoozedUntil,
        mutedFolders: muted,
      ),
    );
  }

  void _commit(MissionTriageState next) {
    state = next;
    _storage.setString(_storageKey, jsonEncode(next.toJsonMap()));
  }
}

extension on MissionTriageState {
  Map<String, dynamic> toJsonMap() => {
    'p': pinnedSessions.toList(),
    's': snoozedUntil,
    'm': mutedFolders.toList(),
  };
}

final missionTriageProvider = NotifierProvider<MissionTriageNotifier,
    MissionTriageState>(MissionTriageNotifier.new);
