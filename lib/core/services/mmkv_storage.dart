import 'dart:async';
import '../models/settings.dart';

class MMKVStorage {
  static final MMKVStorage _instance = MMKVStorage._();
  MMKVStorage._();
  factory MMKVStorage() => _instance;

  static Future<void> initialize() async {}

  Future<Settings> getSettings() async {
    return Settings();
  }

  Future<void> saveSettings(Settings settings) async {}

  Future<void> clearSettings() async {}

  Future<String?> getSessionDraft(String sessionId) async => null;

  Future<void> saveSessionDraft(String sessionId, String draft) async {}

  Future<void> removeSessionDraft(String sessionId) async {}

  Future<Map<String, String>> getSessionDrafts() async => {};

  Future<void> clearSessionDrafts() async {}

  Future<String?> getSessionPermissionMode(String sessionId) async => null;

  Future<void> saveSessionPermissionMode(String sessionId, String mode) async {}

  Future<void> removeSessionPermissionMode(String sessionId) async {}

  Future<Map<String, String>> getSessionPermissionModes() async => {};

  Future<void> clearSessionPermissionModes() async {}

  Future<void> clearAll() async {}
}

class ServerConfigStorage {
  static final ServerConfigStorage _instance = ServerConfigStorage._();
  ServerConfigStorage._();
  factory ServerConfigStorage() => _instance;

  static Future<void> initialize() async {}

  String? getServerUrl() => null;

  void setServerUrl(String? url) {}

  bool isUsingCustomServer() => false;

  void saveServerUrlError(String error) {}

  String? getLastServerUrlError() => null;

  void clearLastServerUrlError() {}

  void clearAll() {}
}
