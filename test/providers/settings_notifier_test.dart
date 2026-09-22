import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/settings_update.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/repositories/settings_repository.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/storage_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:riverpod/riverpod.dart';

class _RecordingSettingsRepository extends Fake implements SettingsRepository {
  final writes = <Map<String, dynamic>>[];
  final snapshot = <String, dynamic>{};
  int failuresRemaining = 0;

  @override
  Future<void> applySettings(Map<String, dynamic> delta) async {
    writes.add(Map<String, dynamic>.from(delta));
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('settings sync failed');
    }
    snapshot.addAll(delta);
  }
}

// Stub that overrides updateSetting to avoid touching MMKV storage.
class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    // Skip storage; apply only the in-memory update.
    state = SettingsUpdate.copyWithUpdated(state, key, value);
  }
}

ProviderContainer makeContainer() {
  return ProviderContainer(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(),
      ),
    ],
  );
}

void main() {
  group('SettingsNotifier batch updates', () {
    late ProviderContainer container;
    late _RecordingSettingsRepository repository;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await MMKVStorage.initialize();
      await MMKVStorage().clearAll();
      SettingsStorage().resetForTests();
      repository = _RecordingSettingsRepository();
      container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      sync.isInitialized = true;
    });

    tearDown(() {
      sync.isInitialized = false;
      SettingsStorage().resetForTests();
      container.dispose();
    });

    test(
      'publishes all keys immediately and preserves a concurrent edit',
      () async {
        final notifier = container.read(settingsNotifierProvider.notifier);
        final batch = notifier.applySettings({
          'themeMode': 'dark',
          'showLineNumbers': false,
        });
        final immediate = container.read(settingsNotifierProvider);
        expect(immediate.themeMode, 'dark');
        expect(immediate.showLineNumbers, isFalse);

        final edit = notifier.updateSetting('compactSessionView', true);
        await Future.wait([batch, edit]);

        final completed = container.read(settingsNotifierProvider);
        expect(completed.themeMode, 'dark');
        expect(completed.showLineNumbers, isFalse);
        expect(completed.compactSessionView, isTrue);
      },
    );

    test('overlapping batches keep both sets of local changes', () async {
      final notifier = container.read(settingsNotifierProvider.notifier);
      await Future.wait([
        notifier.applySettings({'themeMode': 'dark'}),
        notifier.applySettings({'compactSessionView': true}),
      ]);

      final settings = container.read(settingsNotifierProvider);
      expect(settings.themeMode, 'dark');
      expect(settings.compactSessionView, isTrue);
    });

    test('a newer same-key edit wins in memory, storage, and sync', () async {
      final notifier = container.read(settingsNotifierProvider.notifier);
      final batch = notifier.applySettings({
        'themeMode': 'dark',
        'compactSessionView': true,
      });
      final edit = notifier.updateSetting('compactSessionView', false);
      expect(
        container.read(settingsNotifierProvider).compactSessionView,
        false,
      );

      await Future.wait([batch, edit]);
      await SettingsStorage().suspend();
      SettingsStorage().resetForTests();

      final persisted = await SettingsStorage().getSettings();
      expect(persisted.themeMode, 'dark');
      expect(persisted.compactSessionView, isFalse);
      expect(repository.snapshot['compactSessionView'], isFalse);
      expect(repository.writes, [
        {'themeMode': 'dark', 'compactSessionView': true},
        {'compactSessionView': false},
      ]);
      expect(
        container.read(settingsNotifierProvider).compactSessionView,
        isFalse,
      );
    });

    test('a failed edit does not block a later queued edit', () async {
      final notifier = container.read(settingsNotifierProvider.notifier);
      repository.failuresRemaining = 1;
      final first = notifier.applySettings({'themeMode': 'dark'});
      final second = notifier.updateSetting('themeMode', 'light');

      await expectLater(first, throwsStateError);
      await second;

      expect(repository.snapshot['themeMode'], 'light');
      expect((await SettingsStorage().getSettings()).themeMode, 'light');
      expect(container.read(settingsNotifierProvider).themeMode, 'light');
    });

    test(
      'clearing settings cancels edits still waiting for persistence',
      () async {
        final notifier = container.read(settingsNotifierProvider.notifier);
        final edit = notifier.applySettings({'themeMode': 'dark'});
        notifier.clear();
        await edit;

        expect(repository.writes, isEmpty);
        expect(container.read(settingsNotifierProvider).themeMode, 'system');
        expect((await SettingsStorage().getSettings()).themeMode, 'system');
      },
    );

    test('syncs serializable values and excludes rejected keys', () async {
      final profile = AIBackendProfile(id: 'custom', name: 'Custom');
      await container.read(settingsNotifierProvider.notifier).applySettings({
        'profiles': [profile],
        'unknownLegacySetting': true,
      });

      expect(repository.writes, hasLength(1));
      expect(repository.writes.single, {
        'profiles': [profile.toJson()],
      });
      expect(() => jsonEncode(repository.writes.single), returnsNormally);
    });

    test('a batch with no accepted keys does not reach the server', () async {
      await container.read(settingsNotifierProvider.notifier).applySettings({
        'unknownLegacySetting': true,
      });

      expect(repository.writes, isEmpty);
    });
  });

  group('SettingsNotifier', () {
    test('initial state has default Settings values', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);

      expect(settings, isA<Settings>());
      expect(settings.themeMode, 'system');
      expect(settings.compactSessionView, isFalse);
      expect(settings.sessionsViewStyle, 'mission_control');
      expect(settings.expandTodos, isTrue);
      expect(settings.showLineNumbers, isTrue);
      expect(settings.agentInputEnterToSend, isFalse);
      expect(settings.avatarStyle, 'brutalist');
    });

    test('initial state has correct defaults for all bool fields', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);

      expect(settings.viewInline, isFalse);
      expect(settings.hideToolCalls, isFalse);
      expect(settings.analyticsOptOut, isFalse);
      expect(settings.experiments, isFalse);
      expect(settings.markdownCopyV2, isFalse);
      expect(settings.useEnhancedSessionWizard, isFalse);
      expect(settings.alwaysShowContextSize, isFalse);
      expect(settings.developerModeEnabled, isFalse);
      expect(settings.showFlavorIcons, isFalse);
      expect(settings.hideInactiveSessions, isFalse);
      expect(settings.reviewPromptAnswered, isFalse);
    });

    test('updateSetting compactSessionView changes state to true', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('compactSessionView', true);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.compactSessionView, isTrue);
    });

    test('updateSetting sessionsViewStyle changes state to folder', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('sessionsViewStyle', 'folder');

      final settings = c.read(settingsNotifierProvider);
      expect(settings.sessionsViewStyle, 'folder');
    });

    test('updateSetting themeMode changes state to dark', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('themeMode', 'dark');

      final settings = c.read(settingsNotifierProvider);
      expect(settings.themeMode, 'dark');
    });

    test('updateSetting themeMode changes state to light', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('themeMode', 'light');

      final settings = c.read(settingsNotifierProvider);
      expect(settings.themeMode, 'light');
    });

    test('updateSetting viewInline changes state to true', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('viewInline', true);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.viewInline, isTrue);
    });

    test('updateSetting hideToolCalls changes state to true', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('hideToolCalls', true);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.hideToolCalls, isTrue);
    });

    test('updateSetting expandTodos changes state to false', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('expandTodos', false);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.expandTodos, isFalse);
    });

    test('updateSetting showLineNumbers changes state to false', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('showLineNumbers', false);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.showLineNumbers, isFalse);
    });

    test(
      'updateSetting agentInputEnterToSend changes state to false',
      () async {
        final c = makeContainer();
        addTearDown(c.dispose);
        final notifier = c.read(settingsNotifierProvider.notifier);

        await notifier.updateSetting('agentInputEnterToSend', false);

        final settings = c.read(settingsNotifierProvider);
        expect(settings.agentInputEnterToSend, isFalse);
      },
    );

    test('updateSetting avatarStyle changes state', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('avatarStyle', 'gradient');

      final settings = c.read(settingsNotifierProvider);
      expect(settings.avatarStyle, 'gradient');
    });

    test('multiple settings can be updated independently', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('themeMode', 'dark');
      await notifier.updateSetting('compactSessionView', true);
      await notifier.updateSetting('analyticsOptOut', true);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.themeMode, 'dark');
      expect(settings.compactSessionView, isTrue);
      expect(settings.analyticsOptOut, isTrue);
    });

    test('settings state does not affect other container instances', () async {
      final c1 = makeContainer();
      addTearDown(c1.dispose);
      await c1
          .read(settingsNotifierProvider.notifier)
          .updateSetting('themeMode', 'dark');

      // A fresh container should start with defaults.
      final c2 = makeContainer();
      addTearDown(c2.dispose);
      final settings2 = c2.read(settingsNotifierProvider);
      expect(settings2.themeMode, 'system');
    });

    test('schemaVersion defaults to 2', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);
      expect(settings.schemaVersion, 2);
    });

    test('favoriteDirectories has default values', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);
      expect(settings.favoriteDirectories, isNotEmpty);
      expect(settings.favoriteDirectories, contains('~/src'));
    });

    test('recentMachinePaths starts empty', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);
      expect(settings.recentMachinePaths, isEmpty);
    });

    test('profiles starts empty', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);
      expect(settings.profiles, isEmpty);
    });

    test('fromJson falls back to defaults for null server fields', () {
      final settings = Settings.fromJson({
        'themeMode': null,
        'viewInline': null,
        'recentMachinePaths': null,
        'profiles': null,
        'favoriteDirectories': null,
        'favoriteMachines': null,
        'folders': null,
        'dismissedCLIWarnings': null,
      });

      expect(settings.themeMode, 'system');
      expect(settings.viewInline, isFalse);
      expect(settings.recentMachinePaths, isEmpty);
      expect(settings.profiles, isEmpty);
      expect(
        settings.favoriteDirectories,
        equals(['~/src', '~/Desktop', '~/Documents']),
      );
      expect(settings.favoriteMachines, isEmpty);
      expect(settings.folders, isEmpty);
      expect(settings.dismissedCLIWarnings.perMachine, isEmpty);
    });

    test(
      'unknown setting key throws typed exception from dispatcher',
      () async {
        final c = makeContainer();
        addTearDown(c.dispose);
        final notifier = c.read(settingsNotifierProvider.notifier);

        // The test stub bypasses the production catch-and-warn behavior and
        // calls `SettingsUpdate.copyWithUpdated` directly, so dev typos still
        // surface as a typed exception. Production callers
        // (SettingsNotifier.updateSetting, applyRemoteSettingsPatch,
        // SettingsStorage.updateSetting) catch this and log a warning so
        // legacy/forward-compat keys do not crash the app.
        expect(
          () => notifier.updateSetting('notARealSetting', true),
          throwsA(isA<UnknownSettingsKeyException>()),
        );
      },
    );

    test(
      'production SettingsNotifier.updateSetting does not throw on '
      'unknown key (regression: HAPPY_FLUTTER-3C6 ttsUseOffline crash)',
      () async {
        // Use the real notifier (not the storage-free stub) so the
        // production try/catch around `SettingsUpdate.copyWithUpdated`
        // runs. We never reach the storage write for an unknown key
        // because the dispatcher returns early after logging.
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final notifier = c.read(settingsNotifierProvider.notifier);

        // Snapshot a known field before the call so we can verify no
        // state change happened either.
        final before = c.read(settingsNotifierProvider).themeMode;

        await expectLater(
          notifier.updateSetting('totallyUnknownLegacyKey', true),
          completes,
        );

        // The unknown key must not have flipped any real field.
        expect(c.read(settingsNotifierProvider).themeMode, before);
      },
    );
  });
}
