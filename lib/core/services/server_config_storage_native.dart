import 'package:mmkv/mmkv.dart';

import 'logger_service.dart' show logger;

/// Server configuration storage using separate MMKV instance.
/// This persists across logouts and is separate from user data.
class ServerConfigStorage {
  factory ServerConfigStorage() => _instance;
  ServerConfigStorage._();
  static final ServerConfigStorage _instance =
      ServerConfigStorage._();

  MMKV? _mmkv;
  bool _initialized = false;

  static const String _serverUrlKey = 'custom-server-url';
  static const String _serverUrlErrorKey =
      'last-server-url-error';

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  /// Ensure initialized synchronously (for sync getters).
  void _syncInit() {
    if (!_initialized) {
      try {
        _mmkv = MMKV('server-config');
        _initialized = true;
      } catch (e) {
        logger.warning(
          'ServerConfigStorage: Sync init failed: $e',
        );
      }
    }
  }

  /// Initialize server config MMKV instance
  static Future<void> initialize() async {
    if (_instance._initialized) return;

    try {
      await MMKV.initialize();
      _instance._mmkv = MMKV('server-config');
      _instance._initialized = true;
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Initialization failed: $e',
      );
      rethrow;
    }
  }

  /// Get custom server URL
  String? getServerUrl() {
    _syncInit();
    if (!_initialized) return null;
    try {
      return _mmkv?.decodeString(_serverUrlKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to get server URL: $e',
      );
      return null;
    }
  }

  /// Set custom server URL
  Future<void> setServerUrl(String? url) async {
    await _ensureInitialized();
    try {
      if (url != null && url.trim().isNotEmpty) {
        _mmkv?.encodeString(_serverUrlKey, url.trim());
      } else {
        _mmkv?.removeValue(_serverUrlKey);
      }
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to set server URL: $e',
      );
      rethrow;
    }
  }

  /// Check if using custom server URL
  bool isUsingCustomServer() {
    final customUrl = getServerUrl();
    return customUrl != null && customUrl.isNotEmpty;
  }

  /// Save server URL error for display on auth screen
  Future<void> saveServerUrlError(String error) async {
    await _ensureInitialized();
    try {
      _mmkv?.encodeString(_serverUrlErrorKey, error);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to save server URL error',
        e,
      );
    }
  }

  /// Get the last server URL error
  String? getLastServerUrlError() {
    _syncInit();
    if (!_initialized) return null;
    try {
      return _mmkv?.decodeString(_serverUrlErrorKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to get server URL error',
        e,
      );
      return null;
    }
  }

  /// Clear the last server URL error
  Future<void> clearLastServerUrlError() async {
    await _ensureInitialized();
    try {
      _mmkv?.removeValue(_serverUrlErrorKey);
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to clear server URL error',
        e,
      );
    }
  }

  /// Clear all server config data
  Future<void> clearAll() async {
    await _ensureInitialized();
    try {
      _mmkv?.clearAll();
    } catch (e) {
      logger.warning(
        'ServerConfigStorage: Failed to clear all: $e',
      );
    }
  }
}
