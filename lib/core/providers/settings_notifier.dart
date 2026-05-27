import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../crdt/settings_crdt.dart';
import '../models/settings.dart';
import '../models/settings_update.dart';
import '../services/logger_service.dart' show logger;
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '_shared.dart';

class SettingsNotifier extends Notifier<Settings> {
  final _storage = SettingsStorage();
  // CRDT state for the settings domain (item #3 of the architecture
  // overhaul). Replaces the pessimistic apply-then-await round-trip
  // with an LWW-Map: writes are immediate locally, the wire payload
  // carries an (timestamp, replicaId) tag, and inbound updates merge
  // commutatively in [applyRemoteSettingPatch].
  late final SettingsCrdt _crdt = SettingsCrdt(
    replicaId: 'local-${DateTime.now().microsecondsSinceEpoch}',
  );
  int _lastDataChangeCounter = -1;

  @override
  Settings build() => Settings();

  Future<void> loadSettings() async {
    final settings = await _storage.getSettings();
    state = settings;
    // Sync developer mode to logger so DevLogsScreen captures all logs
    // even in release builds when developer mode was enabled previously.
    logger.setDeveloperMode(settings.developerModeEnabled);
  }

  Future<void> loadLocalSettings() async {
    final settings = await _storage.getLocalSettings();
    state = settings;
    logger.setDeveloperMode(settings.developerModeEnabled);
  }

  void clear() {
    state = Settings();
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.settings);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.settingsSnapshot;
    if (state == next) return;
    // Preserve local-only settings that the server doesn't
    // know about — sync.settingsSnapshot defaults them to
    // false, which overwrites the user's local choice.
    final preserved = next.copyWith(
      developerModeEnabled: state.developerModeEnabled,
    );
    state = preserved;
  }

  Future<void> refreshFromSync() => refreshSyncDomain(
        invalidate: () => sync.settingsSync,
        name: 'settings',
        reload: loadFromSync,
      );

  Future<void> updateSetting<T>(String key, T value) async {
    // Update provider state synchronously (before yielding to the event
    // loop) so that other screens see the change immediately.  Without
    // this, callers that use `unawaited(updateSetting(...))` would leave
    // a window where `ref.read(settingsNotifierProvider)` still returns
    // the old value — e.g. NewSessionScreen reading `lastUsedProfile`.
    try {
      state = SettingsUpdate.copyWithUpdated(state, key, value);
    } on UnknownSettingsKeyException catch (e) {
      // Direct local writes shouldn't hit this path in production
      // (call sites are all hard-coded), but if a future rename leaves
      // a stale identifier behind we'd rather log loudly than crash.
      // Regression guard for GlitchTip HAPPY_FLUTTER-3C6: a build that
      // shipped a TTS toggle calling `updateSetting('ttsUseOffline', ...)`
      // before the dispatcher had the matching case crashed fatally.
      logger.warning(
        'Dropping unknown settings key "${e.key}" from local update',
      );
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Settings: dropped unknown key from local update',
            category: 'settings.unknownKey',
            level: SentryLevel.warning,
            data: {'key': e.key},
          ),
        ),
      );
      return;
    }
    // Stamp the CRDT cell so that concurrent edits across replicas
    // converge. The wire patch is unused on the existing `applySettings`
    // path (the server still expects the bare value) but is available
    // to callers that want to ship LWW-tagged updates today.
    _crdt.updateSetting(key, value);
    await _storage.updateSetting(key, value);

    // Sync developer mode to logger so DevLogsScreen can capture all logs
    // even in release builds when developer mode is enabled.
    if (key == 'developerModeEnabled') {
      logger.setDeveloperMode(value as bool);
    }

    if (sync.isInitialized) {
      final syncValue = SettingsUpdate.toSyncValue(key, value);
      await sync.applySettings({key: syncValue});
    }
  }

  /// Applies a remote LWW-tagged settings patch (item #3). Idempotent
  /// and commutative; safe to call from socket pushes that arrive out
  /// of order. Returns whether anything changed.
  bool applyRemoteSettingsPatch(Map<String, Object?> patch) {
    final beforeSnapshot = _crdt.snapshot();
    _crdt.applyRemote(patch);
    final afterSnapshot = _crdt.snapshot();
    var changed = false;
    final next = state;
    Settings updated = next;
    for (final entry in afterSnapshot.entries) {
      if (beforeSnapshot[entry.key] == entry.value) continue;
      try {
        updated = SettingsUpdate.copyWithUpdated(
            updated, entry.key, entry.value);
      } on UnknownSettingsKeyException catch (e) {
        // Remote CRDT patches may carry keys this build no longer
        // knows about (renamed or removed in a newer/older app
        // version). Drop them instead of crashing the merge.
        logger.warning(
          'Dropping unknown settings key "${e.key}" from remote patch',
        );
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'Settings: dropped unknown key from remote patch',
              category: 'settings.unknownKey',
              level: SentryLevel.warning,
              data: {'key': e.key},
            ),
          ),
        );
        continue;
      }
      changed = true;
    }
    if (changed) state = updated;
    return changed;
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  () {
    return SettingsNotifier();
  },
);
