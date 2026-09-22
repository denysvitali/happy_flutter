import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/storage_service.dart';

void main() {
  final storage = SettingsStorage();
  late FlutterSecureStoragePlatform originalPlatform;

  setUp(() async {
    originalPlatform = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    storage.resetForTests();
    await MMKVStorage.initialize();
    await MMKVStorage().clearAll();
  });

  tearDown(() {
    storage.resetForTests();
    FlutterSecureStoragePlatform.instance = originalPlatform;
  });

  Future<void> seedProfile() async {
    await storage.saveSettings(
      Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'custom',
            name: 'Custom',
            openaiConfig: OpenAIConfig(apiKey: 'stored-key'),
          ),
        ],
    );
    storage.resetForTests();
  }

  test('saving a lazy snapshot keeps its profile key hydratable', () async {
    await seedProfile();
    final settings = await storage.getSettings();
    expect(settings.profiles.single.openaiConfig!.apiKey, isNull);

    settings.themeMode = 'dark';
    await storage.saveSettings(settings);

    final profile = await storage.hydrateProfileApiKeys('custom');
    expect(profile!.openaiConfig!.apiKey, 'stored-key');
  });

  test(
    'local settings reads preserve hydrated keys and pending edits',
    () async {
      await seedProfile();
      await storage.hydrateProfileApiKeys('custom');
      await storage.updateSetting('themeMode', 'dark');

      final local = await storage.getLocalSettings();
      expect(local.themeMode, 'dark');
      expect(local.profiles.single.openaiConfig!.apiKey, 'stored-key');
      final profile = await storage.hydrateProfileApiKeys('custom');
      expect(profile!.openaiConfig!.apiKey, 'stored-key');
    },
  );

  test(
    'hydrating inference key before settings load retains the key',
    () async {
      await APIKeyStorage().setInferenceOpenAIKey('inference-key');

      expect(await storage.hydrateInferenceOpenAIKey(), 'inference-key');
      final settings = await storage.getSettings();
      expect(settings.inferenceOpenAIKey, 'inference-key');
      expect(await storage.hydrateInferenceOpenAIKey(), 'inference-key');
    },
  );

  test('suspending flushes a pending settings change', () async {
    await storage.updateSetting('themeMode', 'dark');

    await storage.suspend();
    storage.resetForTests();

    expect((await storage.getSettings()).themeMode, 'dark');
  });

  test(
    'overlapping updates preserve both values in durable settings',
    () async {
      await Future.wait([
        storage.updateSetting('themeMode', 'dark'),
        storage.updateSetting('viewInline', true),
      ]);
      await storage.suspend();
      storage.resetForTests();

      final settings = await storage.getSettings();
      expect(settings.themeMode, 'dark');
      expect(settings.viewInline, isTrue);
    },
  );

  for (final eager in [false, true]) {
    test(
      'delayed ${eager ? 'eager' : 'profile'} hydration preserves edits',
      () async {
        await seedProfile();
        final platform = _DelayedReadStorage({
          'openai_config_key_custom': 'stored-key',
        });
        FlutterSecureStoragePlatform.instance = platform;
        await storage.getSettings();

        final hydration = eager
            ? storage.getSettingsWithApiKeys()
            : storage.hydrateProfileApiKeys('custom');
        await platform.readStarted.future;
        final edit = storage.updateSetting('themeMode', 'dark');
        platform.releaseRead.complete();
        await hydration;
        await edit;

        final settings = await storage.getSettings();
        expect(settings.themeMode, 'dark');
        expect(settings.profiles.single.openaiConfig!.apiKey, 'stored-key');
        final profile = await storage.hydrateProfileApiKeys('custom');
        expect(profile!.openaiConfig!.apiKey, 'stored-key');
      },
    );
  }
}

class _DelayedReadStorage extends TestFlutterSecureStoragePlatform {
  _DelayedReadStorage(super.data);

  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final value = await super.read(key: key, options: options);
    if (key == 'openai_config_key_custom' && !readStarted.isCompleted) {
      readStarted.complete();
      await releaseRead.future;
    }
    return value;
  }
}
