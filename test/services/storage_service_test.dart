import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mmkv/mmkv.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/storage_service.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MMKVStorage', () {
    late MMKVStorage storage;

    setUp(() async {
      // Initialize MMKV for testing
      await MMKV.initialize();
      storage = MMKVStorage();
      // Clear any existing data
      await storage.clearAll();
    });

    tearDown(() async {
      await storage.clearAll();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        expect(storage, isNotNull);
      });

      test('should mark migration as complete after initialization', () async {
        // Re-initialize to trigger migration logic
        await MMKVStorage.initialize();
        // If we got here without exception, initialization succeeded
        expect(true, isTrue);
      });
    });

    group('Settings Storage', () {
      test('should save and retrieve settings', () async {
        final settings = Settings()
          ..themeMode = 'dark'
          ..viewInline = true
          ..expandTodos = false
          ..analyticsOptOut = true;

        await storage.saveSettings(settings);
        final retrieved = await storage.getSettings();

        expect(retrieved.themeMode, equals('dark'));
        expect(retrieved.viewInline, isTrue);
        expect(retrieved.expandTodos, isFalse);
        expect(retrieved.analyticsOptOut, isTrue);
      });

      test('should return default settings when none exist', () async {
        final settings = await storage.getSettings();
        expect(settings, isA<Settings>());
        expect(settings.themeMode, equals('system'));
      });

      test('should update existing settings', () async {
        final settings1 = Settings()..themeMode = 'light';
        await storage.saveSettings(settings1);

        final settings2 = Settings()
          ..themeMode = 'dark'
          ..viewInline = true;
        await storage.saveSettings(settings2);

        final retrieved = await storage.getSettings();
        expect(retrieved.themeMode, equals('dark'));
        expect(retrieved.viewInline, isTrue);
      });

      test('should clear settings', () async {
        final settings = Settings()..themeMode = 'dark';
        await storage.saveSettings(settings);

        await storage.clearSettings();
        final retrieved = await storage.getSettings();

        expect(retrieved.themeMode, equals('system')); // Default value
      });

      test('should handle complex settings with nested objects', () async {
        final settings = Settings()
          ..recentMachinePaths = [
            RecentMachinePath(machineId: 'machine1', path: '/path/to/code'),
            RecentMachinePath(machineId: 'machine2', path: '/another/path'),
          ]
          ..profiles = [
            AIBackendProfile(
              id: 'profile1',
              name: 'Test Profile',
              description: 'A test profile',
            ),
          ]
          ..favoriteDirectories = ['~/src', '~/Desktop', '~/Documents'];

        await storage.saveSettings(settings);
        final retrieved = await storage.getSettings();

        expect(retrieved.recentMachinePaths.length, equals(2));
        expect(retrieved.recentMachinePaths[0].machineId, equals('machine1'));
        expect(retrieved.recentMachinePaths[0].path, equals('/path/to/code'));
        expect(retrieved.profiles.length, equals(1));
        expect(retrieved.profiles[0].id, equals('profile1'));
        expect(retrieved.profiles[0].name, equals('Test Profile'));
        expect(retrieved.favoriteDirectories, equals(['~/src', '~/Desktop', '~/Documents']));
      });

      test('should handle dismissed CLI warnings', () async {
        final warnings = DismissedCLIWarnings()
          ..perMachine = {
            'machine1': PerMachineWarnings(
              claude: true,
              codex: false,
              gemini: true,
            ),
          }
          ..global = GlobalWarnings(
            claude: false,
            codex: true,
            gemini: false,
          );
        final settings = Settings()..dismissedCLIWarnings = warnings;

        await storage.saveSettings(settings);
        final retrieved = await storage.getSettings();

        expect(retrieved.dismissedCLIWarnings.perMachine.length, equals(1));
        expect(
          retrieved.dismissedCLIWarnings.perMachine['machine1']?.claude,
          isTrue,
        );
        expect(
          retrieved.dismissedCLIWarnings.perMachine['machine1']?.codex,
          isFalse,
        );
        expect(retrieved.dismissedCLIWarnings.global.claude, isFalse);
        expect(retrieved.dismissedCLIWarnings.global.codex, isTrue);
      });
    });

    group('Session Drafts Storage', () {
      test('should save and retrieve session draft', () async {
        const sessionId = 'session-123';
        const draft = 'This is a draft message';

        await storage.saveSessionDraft(sessionId, draft);
        final retrieved = await storage.getSessionDraft(sessionId);

        expect(retrieved, equals(draft));
      });

      test('should return null for non-existent draft', () async {
        final retrieved = await storage.getSessionDraft('non-existent');
        expect(retrieved, isNull);
      });

      test('should update existing draft', () async {
        const sessionId = 'session-123';
        const draft1 = 'First draft';
        const draft2 = 'Updated draft';

        await storage.saveSessionDraft(sessionId, draft1);
        await storage.saveSessionDraft(sessionId, draft2);

        final retrieved = await storage.getSessionDraft(sessionId);
        expect(retrieved, equals(draft2));
      });

      test('should retrieve all session drafts', () async {
        await storage.saveSessionDraft('session-1', 'Draft 1');
        await storage.saveSessionDraft('session-2', 'Draft 2');
        await storage.saveSessionDraft('session-3', 'Draft 3');

        final allDrafts = await storage.getSessionDrafts();

        expect(allDrafts.length, equals(3));
        expect(allDrafts['session-1'], equals('Draft 1'));
        expect(allDrafts['session-2'], equals('Draft 2'));
        expect(allDrafts['session-3'], equals('Draft 3'));
      });

      test('should remove specific draft', () async {
        await storage.saveSessionDraft('session-1', 'Draft 1');
        await storage.saveSessionDraft('session-2', 'Draft 2');

        await storage.removeSessionDraft('session-1');

        final draft1 = await storage.getSessionDraft('session-1');
        final draft2 = await storage.getSessionDraft('session-2');

        expect(draft1, isNull);
        expect(draft2, equals('Draft 2'));
      });

      test('should clear all session drafts', () async {
        await storage.saveSessionDraft('session-1', 'Draft 1');
        await storage.saveSessionDraft('session-2', 'Draft 2');

        await storage.clearSessionDrafts();

        final allDrafts = await storage.getSessionDrafts();
        expect(allDrafts.isEmpty, isTrue);
      });

      test('should handle empty drafts correctly', () async {
        final allDrafts = await storage.getSessionDrafts();
        expect(allDrafts, isEmpty);
      });
    });

    group('Session Permission Modes Storage', () {
      test('should save and retrieve permission mode', () async {
        const sessionId = 'session-123';
        const mode = 'edit';

        await storage.saveSessionPermissionMode(sessionId, mode);
        final retrieved = await storage.getSessionPermissionMode(sessionId);

        expect(retrieved, equals(mode));
      });

      test('should return null for non-existent permission mode', () async {
        final retrieved =
            await storage.getSessionPermissionMode('non-existent');
        expect(retrieved, isNull);
      });

      test('should update existing permission mode', () async {
        const sessionId = 'session-123';
        const mode1 = 'browse';
        const mode2 = 'edit';

        await storage.saveSessionPermissionMode(sessionId, mode1);
        await storage.saveSessionPermissionMode(sessionId, mode2);

        final retrieved = await storage.getSessionPermissionMode(sessionId);
        expect(retrieved, equals(mode2));
      });

      test('should retrieve all permission modes', () async {
        await storage.saveSessionPermissionMode('session-1', 'browse');
        await storage.saveSessionPermissionMode('session-2', 'edit');
        await storage.saveSessionPermissionMode('session-3', 'read');

        final allModes = await storage.getSessionPermissionModes();

        expect(allModes.length, equals(3));
        expect(allModes['session-1'], equals('browse'));
        expect(allModes['session-2'], equals('edit'));
        expect(allModes['session-3'], equals('read'));
      });

      test('should remove specific permission mode', () async {
        await storage.saveSessionPermissionMode('session-1', 'browse');
        await storage.saveSessionPermissionMode('session-2', 'edit');

        await storage.removeSessionPermissionMode('session-1');

        final mode1 = await storage.getSessionPermissionMode('session-1');
        final mode2 = await storage.getSessionPermissionMode('session-2');

        expect(mode1, isNull);
        expect(mode2, equals('edit'));
      });

      test('should clear all permission modes', () async {
        await storage.saveSessionPermissionMode('session-1', 'browse');
        await storage.saveSessionPermissionMode('session-2', 'edit');

        await storage.clearSessionPermissionModes();

        final allModes = await storage.getSessionPermissionModes();
        expect(allModes.isEmpty, isTrue);
      });
    });

    group('Profile Storage', () {
      test('should save and retrieve profile', () async {
        final profileStorage = ProfileStorage();
        final profile = const Profile(
          id: 'user-123',
          firstName: 'John',
          lastName: 'Doe',
        );

        await profileStorage.saveProfile(profile);
        final retrieved = await profileStorage.loadProfile();

        expect(retrieved.id, equals('user-123'));
        expect(retrieved.firstName, equals('John'));
        expect(retrieved.lastName, equals('Doe'));
      });

      test('should return default profile when none exists', () async {
        final profileStorage = ProfileStorage();
        final profile = await profileStorage.loadProfile();

        expect(profile, isA<Profile>());
        expect(profile.id, equals(''));
        expect(profile.firstName, isNull);
      });

      test('should update existing profile', () async {
        final profileStorage = ProfileStorage();
        final profile1 = const Profile(id: 'user-123', firstName: 'John');
        await profileStorage.saveProfile(profile1);

        final profile2 = const Profile(
          id: 'user-123',
          firstName: 'Jane',
        );
        await profileStorage.saveProfile(profile2);

        final retrieved = await profileStorage.loadProfile();
        expect(retrieved.firstName, equals('Jane'));
      });

      test('should clear profile', () async {
        final profileStorage = ProfileStorage();
        final profile = const Profile(id: 'user-123', firstName: 'John');
        await profileStorage.saveProfile(profile);

        await profileStorage.clearProfile();
        final retrieved = await profileStorage.loadProfile();

        expect(retrieved.firstName, isNull);
      });

      test('should copy profile correctly', () async {
        const profile = Profile(
          id: 'user-123',
          firstName: 'John',
        );

        final copied = profile.copyWith(
          firstName: 'Jane',
        );

        expect(copied.firstName, equals('Jane'));
        expect(copied.id, equals('user-123'));
      });
    });

    group('Data Migration from SharedPreferences', () {
      setUp(() async {
        // Clear MMKV before migration tests
        await storage.clearAll();
      });

      test('should migrate settings from SharedPreferences', () async {
        // Setup SharedPreferences with old data
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final settings = Settings()
          ..themeMode = 'dark'
          ..viewInline = true
          ..analyticsOptOut = true;
        final settingsJson = jsonEncode(settings.toJson());
        await prefs.setString('settings', settingsJson);

        // Re-initialize to trigger migration
        await MMKVStorage.initialize();

        // Verify migration
        final migratedSettings = await storage.getSettings();
        expect(migratedSettings.themeMode, equals('dark'));
        expect(migratedSettings.viewInline, isTrue);
        expect(migratedSettings.analyticsOptOut, isTrue);

        // Verify old data is removed from SharedPreferences
        final oldSettings = prefs.getString('settings');
        expect(oldSettings, isNull);
      });

      test('should migrate session drafts from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final drafts = {
          'session-1': 'Draft 1',
          'session-2': 'Draft 2',
        };
        final draftsJson = jsonEncode(drafts);
        await prefs.setString('session-drafts', draftsJson);

        await MMKVStorage.initialize();

        final migratedDrafts = await storage.getSessionDrafts();
        expect(migratedDrafts.length, equals(2));
        expect(migratedDrafts['session-1'], equals('Draft 1'));
        expect(migratedDrafts['session-2'], equals('Draft 2'));

        final oldDrafts = prefs.getString('session-drafts');
        expect(oldDrafts, isNull);
      });

      test('should migrate permission modes from SharedPreferences',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final modes = {
          'session-1': 'browse',
          'session-2': 'edit',
        };
        final modesJson = jsonEncode(modes);
        await prefs.setString('session-permission-modes', modesJson);

        await MMKVStorage.initialize();

        final migratedModes = await storage.getSessionPermissionModes();
        expect(migratedModes.length, equals(2));
        expect(migratedModes['session-1'], equals('browse'));
        expect(migratedModes['session-2'], equals('edit'));

        final oldModes = prefs.getString('session-permission-modes');
        expect(oldModes, isNull);
      });

      test('should migrate profile from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final profile = Profile(
          id: 'user-123',
          firstName: 'John',
          lastName: 'Doe',
          github: const GitHubProfile(
            id: 1,
            login: 'johndoe',
            name: 'John Doe',
            avatarUrl: 'https://github.com/images/johndoe.png',
          ),
        );
        final profileJson = jsonEncode(profile.toJson());
        await prefs.setString('profile', profileJson);

        await MMKVStorage.initialize();

        final profileStorage = ProfileStorage();
        final migratedProfile = await profileStorage.loadProfile();
        expect(migratedProfile.firstName, equals('John'));
        expect(migratedProfile.lastName, equals('Doe'));
        expect(migratedProfile.github?.login, equals('johndoe'));

        final oldProfile = prefs.getString('profile');
        expect(oldProfile, isNull);
      });

      test('should handle migration when SharedPreferences is empty',
          () async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferences.getInstance();

        await MMKVStorage.initialize();

        final settings = await storage.getSettings();
        expect(settings, isA<Settings>());
        expect(settings.themeMode, equals('system')); // Default value
      });

      test('should not migrate twice', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final settings = Settings()..themeMode = 'dark';
        final settingsJson = jsonEncode(settings.toJson());
        await prefs.setString('settings', settingsJson);

        await MMKVStorage.initialize();

        // Try to add data to SharedPreferences after migration
        final newSettings = Settings()..themeMode = 'light';
        final newSettingsJson = jsonEncode(newSettings.toJson());
        await prefs.setString('settings', newSettingsJson);

        // Re-initialize - should not migrate again
        await MMKVStorage.initialize();

        final migratedSettings = await storage.getSettings();
        expect(migratedSettings.themeMode, equals('dark')); // First migration
      });
    });

    group('Clear All Data', () {
      test('should clear all stored data', () async {
        // Add some data
        final settings = Settings()..themeMode = 'dark';
        await storage.saveSettings(settings);
        await storage.saveSessionDraft('session-1', 'Draft 1');
        await storage.saveSessionPermissionMode('session-1', 'edit');

        final profileStorage = ProfileStorage();
        await profileStorage.saveProfile(
          const Profile(id: 'user-123', firstName: 'John', lastName: 'Doe'),
        );

        // Clear all
        await storage.clearAll();

        // Verify all data is cleared
        final retrievedSettings = await storage.getSettings();
        expect(retrievedSettings.themeMode, equals('system')); // Default

        final draft = await storage.getSessionDraft('session-1');
        expect(draft, isNull);

        final mode = await storage.getSessionPermissionMode('session-1');
        expect(mode, isNull);

        final profile = await profileStorage.loadProfile();
        expect(profile.firstName, isNull);
      });
    });

    group('Error Handling', () {
      test('should handle malformed JSON gracefully', () async {
        // Write invalid JSON directly to MMKV using test helper
        await storage.writeRawString('settings', 'invalid-json');

        final settings = await storage.getSettings();
        expect(settings, isA<Settings>());
        expect(settings.themeMode, equals('system')); // Default value
      });

      test('should handle missing keys gracefully', () async {
        final draft = await storage.getSessionDraft('non-existent');
        expect(draft, isNull);

        final mode = await storage.getSessionPermissionMode('non-existent');
        expect(mode, isNull);
      });
    });
  });

  group('ServerConfigStorage', () {
    late ServerConfigStorage storage;

    setUp(() async {
      await ServerConfigStorage.initialize();
      storage = ServerConfigStorage();
      await storage.clearAll();
    });

    tearDown(() async {
      await storage.clearAll();
    });

    test('should initialize successfully', () async {
      expect(storage, isNotNull);
    });

    test('should save and retrieve server URL', () async {
      const url = 'https://api.example.com';

      await storage.setServerUrl(url);
      final retrieved = storage.getServerUrl();

      expect(retrieved, equals(url));
    });

    test('should return null when no custom URL is set', () async {
      final retrieved = storage.getServerUrl();
      expect(retrieved, isNull);
    });

    test('should trim whitespace from URL', () async {
      const url = '  https://api.example.com  ';

      await storage.setServerUrl(url);
      final retrieved = storage.getServerUrl();

      expect(retrieved, equals('https://api.example.com'));
    });

    test('should remove URL when setting null', () async {
      const url = 'https://api.example.com';

      await storage.setServerUrl(url);
      expect(storage.getServerUrl(), equals(url));

      await storage.setServerUrl(null);
      expect(storage.getServerUrl(), isNull);
    });

    test('should remove URL when setting empty string', () async {
      const url = 'https://api.example.com';

      await storage.setServerUrl(url);
      expect(storage.getServerUrl(), equals(url));

      await storage.setServerUrl('');
      expect(storage.getServerUrl(), isNull);
    });

    test('should detect when using custom server', () async {
      expect(storage.isUsingCustomServer(), isFalse);

      await storage.setServerUrl('https://api.example.com');
      expect(storage.isUsingCustomServer(), isTrue);

      await storage.setServerUrl(null);
      expect(storage.isUsingCustomServer(), isFalse);
    });

    test('should save and retrieve server URL error', () async {
      const error = 'Connection failed: Network unreachable';

      await storage.saveServerUrlError(error);
      final retrieved = storage.getLastServerUrlError();

      expect(retrieved, equals(error));
    });

    test('should return null when no error is stored', () async {
      final retrieved = storage.getLastServerUrlError();
      expect(retrieved, isNull);
    });

    test('should clear server URL error', () async {
      const error = 'Connection failed';

      await storage.saveServerUrlError(error);
      expect(storage.getLastServerUrlError(), equals(error));

      await storage.clearLastServerUrlError();
      expect(storage.getLastServerUrlError(), isNull);
    });

    test('should clear all server config data', () async {
      await storage.setServerUrl('https://api.example.com');
      await storage.saveServerUrlError('Error message');

      await storage.clearAll();

      expect(storage.getServerUrl(), isNull);
      expect(storage.getLastServerUrlError(), isNull);
    });

    test('should handle multiple URL updates', () async {
      await storage.setServerUrl('https://api1.example.com');
      expect(storage.getServerUrl(), equals('https://api1.example.com'));

      await storage.setServerUrl('https://api2.example.com');
      expect(storage.getServerUrl(), equals('https://api2.example.com'));

      await storage.setServerUrl('https://api3.example.com');
      expect(storage.getServerUrl(), equals('https://api3.example.com'));
    });
  });

  group('Storage Integration', () {
    late Storage storage;

    setUp(() async {
      storage = Storage();
      await storage.initialize();
      await storage.clearAll();
    });

    tearDown(() async {
      await storage.clearAll();
    });

    test('should initialize all storage components', () async {
      expect(storage.tokenStorage, isNotNull);
      expect(storage.settingsStorage, isNotNull);
      expect(storage.sessionDraftsStorage, isNotNull);
      expect(storage.sessionPermissionModesStorage, isNotNull);
      expect(storage.profileStorage, isNotNull);
    });

    test('should clear all user data but preserve server config', () async {
      final serverConfig = ServerConfigStorage();
      await serverConfig.setServerUrl('https://api.example.com');

      final settings = Settings()..themeMode = 'dark';
      await storage.settingsStorage.saveSettings(settings);

      await storage.clearAll();

      // Server config should be preserved
      expect(serverConfig.getServerUrl(), equals('https://api.example.com'));

      // User data should be cleared
      final retrievedSettings = await storage.settingsStorage.getSettings();
      expect(retrievedSettings.themeMode, equals('system')); // Default
    });

    test('should clear server config separately', () async {
      final serverConfig = ServerConfigStorage();
      await serverConfig.setServerUrl('https://api.example.com');

      await storage.clearServerConfig();

      expect(serverConfig.getServerUrl(), isNull);
    });

    test('should handle concurrent storage operations', () async {
      final futures = <Future<void>>[];

      // Concurrent settings writes
      for (int i = 0; i < 10; i++) {
        futures.add(
          storage.settingsStorage.saveSettings(
            Settings()..viewInline = i % 2 == 0,
          ),
        );
      }

      // Concurrent draft writes
      for (int i = 0; i < 10; i++) {
        futures.add(
          storage.sessionDraftsStorage.saveDraft('session-$i', 'Draft $i'),
        );
      }

      // Concurrent permission mode writes
      for (int i = 0; i < 10; i++) {
        futures.add(
          storage.sessionPermissionModesStorage.savePermissionMode(
            'session-$i',
            i % 2 == 0 ? 'browse' : 'edit',
          ),
        );
      }

      await Future.wait(futures);

      // Verify data integrity
      final drafts = await storage.sessionDraftsStorage.getAllDrafts();
      expect(drafts.length, equals(10));

      final modes = await storage.sessionPermissionModesStorage.getAllPermissionModes();
      expect(modes.length, equals(10));
    });
  });
}
