import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/auth.dart';
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

  test(
    'credential deletion failure invalidates cache and blocks old credentials',
    () async {
      final token = TokenStorage();
      final platform = _FailingDeleteStorage({});
      FlutterSecureStoragePlatform.instance = platform;
      await token.setCredentials(
        const AuthCredentials(token: 'old', secret: 'secret'),
      );
      platform.failDeletion = true;
      expect(await token.removeCredentials(), isFalse);
      expect(await token.getCredentials(), isNull);
      expect(MMKVStorage().getString('auth-logout-pending'), 'true');
      expect(
        await token.setCredentials(
          const AuthCredentials(token: 'new', secret: 'new-secret'),
        ),
        isFalse,
      );
      platform.failDeletion = false;
      expect(await token.removeCredentials(), isTrue);
      expect(await token.getCredentials(), isNull);
    },
  );

  test('delayed credential read cannot restore logged-out account', () async {
    final token = TokenStorage();
    await token.removeCredentials();
    final platform = _DelayedTokenReadStorage({
      'auth_credentials': jsonEncode(
        const AuthCredentials(token: 'old', secret: 'old-secret').toJson(),
      ),
    });
    FlutterSecureStoragePlatform.instance = platform;
    final read = token.getCredentials();
    await platform.readStarted.future;
    expect(await token.removeCredentials(), isTrue);
    expect(
      await token.setCredentials(
        const AuthCredentials(token: 'new', secret: 'new-secret'),
      ),
      isTrue,
    );
    platform.releaseRead.complete();
    expect(await read, isNull);
    expect((await token.getCredentials())!.token, 'new');
    await token.removeCredentials();
  });

  test(
    'corrupt credential repair cannot delete a newer account write',
    () async {
      final token = TokenStorage();
      await token.removeCredentials();
      final platform = _DelayedCorruptTokenStorage({});
      FlutterSecureStoragePlatform.instance = platform;
      final read = token.getCredentials();
      await platform.deleteStarted.future;
      final write = token.setCredentials(
        const AuthCredentials(token: 'new', secret: 'new-secret'),
      );
      platform.releaseDelete.complete();
      expect(await read, isNull);
      expect(await write, isTrue);
      expect((await token.getCredentials())!.token, 'new');
      final persisted = await platform.read(
        key: 'auth_credentials',
        options: {},
      );
      expect(jsonDecode(persisted!)['token'], 'new');
      await token.removeCredentials();
    },
  );

  test(
    'failed journal write rejects an edit without claiming durability',
    () async {
      await storage.activateAccount('account-a');
      storage.testJournalWrite = (_, _) async => throw StateError('persist');
      await expectLater(
        storage.updateSetting('themeMode', 'dark'),
        throwsStateError,
      );
      expect(MMKVStorage().getString('settings-journal-v1-account-a'), isNull);
      storage.resetForTests();
      await storage.activateAccount('account-a');
      expect((await storage.getSettings()).themeMode, 'system');
    },
  );

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

  test(
    'accepted remote snapshot updates cache before unrelated edit',
    () async {
      await seedProfile();
      await storage.hydrateProfileApiKeys('custom');
      final remote = await storage.getSettings();
      remote.viewInline = true;
      remote.profiles = [
        remote.profiles.single.copyWith(
          openaiConfig: OpenAIConfig(
            baseUrl: 'https://new.example',
            model: 'new',
          ),
        ),
      ];
      await storage.commitSyncedSettings(remote, pending: {}, version: 2);
      await storage.updateSetting('themeMode', 'dark');
      await storage.suspend();
      final profile = await storage.hydrateKeysForProfile(
        remote.profiles.single,
      );
      expect(profile.openaiConfig!.baseUrl, 'https://new.example');
      expect(profile.openaiConfig!.model, 'new');
      expect(profile.openaiConfig!.apiKey, 'stored-key');
      storage.resetForTests();
      final reloaded = await storage.getSettings();
      expect(reloaded.viewInline, isTrue);
      expect(reloaded.themeMode, 'dark');
      expect(reloaded.profiles.single.openaiConfig!.model, 'new');
    },
  );

  test('activation cannot unblock settings after a teardown fence', () async {
    final activation = storage.activateAccount('account-a');
    final rejected = expectLater(activation, throwsStateError);
    await Future<void>.microtask(() {});
    storage.fenceAccountOperations();
    await rejected;
    await expectLater(
      storage.updateSetting('themeMode', 'dark'),
      throwsStateError,
    );
    await storage.clearAccountSettings();
    await storage.activateAccount('account-b');
    await storage.updateSetting('themeMode', 'dark');
  });

  test(
    'teardown drains hydration and cancels queued key-bearing saves',
    () async {
      await seedProfile();
      final platform = _DelayedReadStorage({
        'openai_config_key_custom': 'stored-key',
      });
      FlutterSecureStoragePlatform.instance = platform;
      final hydration = storage.hydrateProfileApiKeys('custom');
      await platform.readStarted.future;
      final save = storage.saveSettings(
        Settings()
          ..profiles = [
            AIBackendProfile(
              id: 'custom',
              name: 'Old',
              openaiConfig: OpenAIConfig(apiKey: 'old-key'),
            ),
          ],
      );
      final cleanup = storage.clearAccountSettings();
      platform.releaseRead.complete();
      await expectLater(hydration, throwsStateError);
      await expectLater(save, throwsStateError);
      await cleanup;
      await APIKeyStorage().clearAllAPIKeys();
      await storage.activateAccount('account-b');
      await storage.updateSetting('themeMode', 'dark');
      await storage.suspend();
      expect((await storage.getSettings()).profiles, isEmpty);
      expect(await APIKeyStorage().getOpenAIConfigKey('custom'), isNull);
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

class _FailingDeleteStorage extends TestFlutterSecureStoragePlatform {
  _FailingDeleteStorage(super.data);
  bool failDeletion = false;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    if (failDeletion) throw StateError('secure storage delete failed');
    await super.delete(key: key, options: options);
  }
}

class _DelayedTokenReadStorage extends TestFlutterSecureStoragePlatform {
  _DelayedTokenReadStorage(super.data);
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final value = await super.read(key: key, options: options);
    if (key == 'auth_credentials' && !readStarted.isCompleted) {
      readStarted.complete();
      await releaseRead.future;
    }
    return value;
  }
}

class _DelayedCorruptTokenStorage extends TestFlutterSecureStoragePlatform {
  _DelayedCorruptTokenStorage(super.data);
  bool corruptRead = true;
  final deleteStarted = Completer<void>();
  final releaseDelete = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == 'auth_credentials' && corruptRead) {
      corruptRead = false;
      throw PlatformException(code: 'AEADBadTagException', message: 'read');
    }
    return super.read(key: key, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == 'auth_credentials' && !deleteStarted.isCompleted) {
      deleteStarted.complete();
      await releaseDelete.future;
    }
    await super.delete(key: key, options: options);
  }
}
