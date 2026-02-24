import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

// Stub that overrides updateSetting to avoid touching MMKV storage.
class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    // Skip storage; apply only the in-memory update.
    state = _applyUpdate(state, key, value);
  }

  Settings _applyUpdate(Settings current, String key, dynamic value) {
    final json = current.toJson();
    json[key] = value;
    return Settings.fromJson(json);
  }
}

ProviderContainer makeContainer() {
  return ProviderContainer(
    overrides: [
      settingsNotifierProvider
          .overrideWith(() => _StorageFreeSettingsNotifier()),
    ],
  );
}

void main() {
  group('SettingsNotifier', () {

    test('initial state has default Settings values', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);

      expect(settings, isA<Settings>());
      expect(settings.themeMode, 'system');
      expect(settings.compactSessionView, isFalse);
      expect(settings.expandTodos, isTrue);
      expect(settings.showLineNumbers, isTrue);
      expect(settings.agentInputEnterToSend, isTrue);
      expect(settings.avatarStyle, 'brutalist');
    });

    test('initial state has correct defaults for all bool fields', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final settings = c.read(settingsNotifierProvider);

      expect(settings.viewInline, isFalse);
      expect(settings.analyticsOptOut, isFalse);
      expect(settings.experiments, isFalse);
      expect(settings.markdownCopyV2, isFalse);
      expect(settings.useEnhancedSessionWizard, isFalse);
      expect(settings.alwaysShowContextSize, isFalse);
      expect(settings.developerModeEnabled, isFalse);
      expect(settings.showFlavorIcons, isFalse);
      expect(settings.hideInactiveSessions, isTrue);
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

    test('updateSetting agentInputEnterToSend changes state to false',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(settingsNotifierProvider.notifier);

      await notifier.updateSetting('agentInputEnterToSend', false);

      final settings = c.read(settingsNotifierProvider);
      expect(settings.agentInputEnterToSend, isFalse);
    });

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
      await c1.read(settingsNotifierProvider.notifier)
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
  });
}
