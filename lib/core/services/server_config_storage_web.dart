import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart' show logger;

/// Web implementation of ServerConfigStorage.
///
/// Uses SharedPreferences with a `server_config.` prefix to namespace
/// keys, mirroring the separate MMKV instance used on native.
class ServerConfigStorage {
  factory ServerConfigStorage() => _instance;
  ServerConfigStorage._();
  static final ServerConfigStorage _instance =
      ServerConfigStorage._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory cache for synchronous getServerUrl / getLastServerUrlError
  String? _cachedServerUrl;
  String? _cachedServerUrlError;
  bool _cacheLoaded = false;

  static const String _prefix = 'server_config.';
  static const String _serverUrlKey = 'custom-server-url';
  static const String _serverUrlErrorKey =
      'last-server-url-error';

  static String _prefixedKey(String key) => '$_prefix$key';

  static Future<void> initialize() async {
    if (_instance._initialized) return;
    try {
      _instance._prefs =
          await SharedPreferences.getInstance();
      _instance._initialized = true;
      _instance._loadCache();
    } catch (e) {
      logger.warning(
        'WebStorage(ServerConfigStorage): init failed: $e',
      );
      rethrow;
    }
  }

  void _loadCache() {
    _cachedServerUrl =
        _prefs?.getString(_prefixedKey(_serverUrlKey));
    _cachedServerUrlError =
        _prefs?.getString(_prefixedKey(_serverUrlErrorKey));
    _cacheLoaded = true;
  }

  Future<SharedPreferences> _getPrefs() async {
    if (!_initialized) await initialize();
    return _prefs!;
  }

  /// Get custom server URL (synchronous via in-memory cache).
  String? getServerUrl() {
    if (!_cacheLoaded && _prefs != null) _loadCache();
    return _cachedServerUrl;
  }

  Future<void> setServerUrl(String? url) async {
    _cachedServerUrl =
        (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    try {
      final prefs = await _getPrefs();
      final key = _prefixedKey(_serverUrlKey);
      if (_cachedServerUrl != null) {
        await prefs.setString(key, _cachedServerUrl!);
      } else {
        await prefs.remove(key);
      }
    } catch (e) {
      logger.warning('WebStorage: failed to set server URL: $e');
      rethrow;
    }
  }

  bool isUsingCustomServer() {
    final url = getServerUrl();
    return url != null && url.isNotEmpty;
  }

  Future<void> saveServerUrlError(String error) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        _prefixedKey(_serverUrlErrorKey),
        error,
      );
      _cachedServerUrlError = error;
    } catch (e) {
      logger.warning(
        'WebStorage: failed to save server URL error: $e',
      );
    }
  }

  String? getLastServerUrlError() {
    if (!_cacheLoaded && _prefs != null) _loadCache();
    return _cachedServerUrlError;
  }

  Future<void> clearLastServerUrlError() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_prefixedKey(_serverUrlErrorKey));
      _cachedServerUrlError = null;
    } catch (e) {
      logger.warning(
        'WebStorage: failed to clear server URL error: $e',
      );
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_prefixedKey(_serverUrlKey));
      await prefs.remove(_prefixedKey(_serverUrlErrorKey));
      _cachedServerUrl = null;
      _cachedServerUrlError = null;
    } catch (e) {
      logger.warning(
        'WebStorage: failed to clear server config: $e',
      );
    }
  }
}
