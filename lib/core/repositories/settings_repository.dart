import 'package:riverpod/riverpod.dart';

import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/settings.dart';
import '../services/sync_service.dart' show sync;
import '../sync/settings_manager.dart';

/// Repository layer for settings, profile, purchases, push token, and
/// native update state. Wraps [SettingsManager] and provides the public
/// surface used by notifiers and screens.
class SettingsRepository {
  const SettingsRepository(this._manager);

  final SettingsManager _manager;

  Settings get settingsSnapshot => _manager.settingsSnapshot;
  int get settingsVersion => _manager.settingsVersion;
  Profile? get profile => _manager.profile;
  Purchases get purchases => _manager.purchases;
  String? get nativeUpdateUrl => _manager.nativeUpdateUrl;
  bool get hasNativeUpdate => _manager.nativeUpdateUrl != null;

  Future<void> syncSettings() => _manager.syncSettings();

  Future<void> applySettings(Map<String, dynamic> delta) =>
      _manager.applySettings(delta);

  Future<void> fetchProfile() => _manager.fetchProfile();

  Future<void> refreshProfile() => _manager.refreshProfile();

  Future<void> refreshPurchases() => _manager.refreshPurchases();

  Future<void> syncPushToken() => _manager.syncPushToken();

  Future<void> fetchNativeUpdate() => _manager.fetchNativeUpdate();
}

/// Provider for the settings manager managed by the sync singleton.
final settingsManagerProvider = Provider<SettingsManager>(
  (ref) => sync.settingsManager!,
);

/// Provider for the settings repository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.read(settingsManagerProvider)),
);
