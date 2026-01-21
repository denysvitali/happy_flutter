import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth.dart';
import '../models/settings.dart';

/// Secure storage for authentication credentials
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._();
  factory TokenStorage() => _instance;
  TokenStorage._();

  static const String _authKey = 'auth_credentials';

  final _secureStorage = const FlutterSecureStorage();
  AuthCredentials? _cachedCredentials;

  /// Get credentials from secure storage
  Future<AuthCredentials?> getCredentials() async {
    if (_cachedCredentials != null) {
      return _cachedCredentials;
    }

    try {
      final stored = await _secureStorage.read(key: _authKey);
      if (stored == null) return null;

      final credentials = AuthCredentials.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      _cachedCredentials = credentials;
      return credentials;
    } catch (e) {
      debugPrint('Error getting credentials: $e');
      return null;
    }
  }

  /// Store credentials securely
  Future<bool> setCredentials(AuthCredentials credentials) async {
    try {
      final json = jsonEncode(credentials.toJson());
      await _secureStorage.write(key: _authKey, value: json);
      _cachedCredentials = credentials;
      return true;
    } catch (e) {
      debugPrint('Error setting credentials: $e');
      return false;
    }
  }

  /// Remove credentials
  Future<bool> removeCredentials() async {
    try {
      await _secureStorage.delete(key: _authKey);
      _cachedCredentials = null;
      return true;
    } catch (e) {
      debugPrint('Error removing credentials: $e');
      return false;
    }
  }

  /// Check if authenticated
  Future<bool> isAuthenticated() async {
    final credentials = await getCredentials();
    return credentials != null;
  }
}

/// Settings storage with persistence
class SettingsStorage {
  static final SettingsStorage _instance = SettingsStorage._();
  factory SettingsStorage() => _instance;
  SettingsStorage._();

  static const String _settingsKey = 'user_settings';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get settings from storage
  Future<Settings> getSettings() async {
    _ensureInitialized();

    final stored = _prefs!.getString(_settingsKey);
    if (stored == null) {
      return Settings();
    }

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return Settings.fromJson(json);
    } catch (e) {
      debugPrint('Error parsing settings: $e');
      return Settings();
    }
  }

  /// Save settings to storage
  Future<void> saveSettings(Settings settings) async {
    _ensureInitialized();

    final json = jsonEncode(settings.toJson());
    await _prefs!.setString(_settingsKey, json);
  }

  /// Update a single setting
  Future<void> updateSetting<T>(String key, T value) async {
    final current = await getSettings();
    final updated = _updateSetting(current, key, value) as Settings;
    await saveSettings(updated);
  }

  dynamic _updateSetting(dynamic settings, String key, dynamic value) {
    final json = settings.toJson();
    json[key] = value;
    return Settings.fromJson(json);
  }

  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError('SettingsStorage not initialized. Call initialize() first.');
    }
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    _ensureInitialized();
    await _prefs!.remove(_settingsKey);
  }
}

/// Combined storage for app data
class Storage {
  static final Storage _instance = Storage._();
  factory Storage() => _instance;
  Storage._();

  final tokenStorage = TokenStorage();
  final settingsStorage = SettingsStorage();

  /// Initialize all storage
  Future<void> initialize() async {
    await settingsStorage.initialize();
  }

  /// Clear all storage
  Future<void> clearAll() async {
    await tokenStorage.removeCredentials();
    await settingsStorage.clearSettings();
  }
}
