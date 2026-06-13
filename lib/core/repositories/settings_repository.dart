import 'package:riverpod/riverpod.dart';

import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/settings.dart';
import '../services/sync_service.dart';

/// Repository layer for settings, profile, purchases, push token, and
/// native update state. Wraps the corresponding Sync methods while
/// [SettingsManager] extraction is in progress.
class SettingsRepository {
  const SettingsRepository();

  Settings get settingsSnapshot => sync.settingsSnapshot;
  int get settingsVersion => sync.settingsVersion;
  Profile? get profile => sync.profile;
  Purchases get purchases => sync.purchases;
  String? get nativeUpdateUrl => sync.nativeUpdateUrl;
  bool get hasNativeUpdate => sync.hasNativeUpdate;

  Future<void> syncSettings() => sync.syncSettings();

  Future<void> applySettings(Map<String, dynamic> delta) =>
      sync.applySettings(delta);

  Future<void> fetchProfile() => sync.fetchProfile();

  Future<void> refreshProfile() => sync.refreshProfile();

  Future<void> refreshPurchases() => sync.refreshPurchases();

  Future<void> syncPushToken() => sync.syncPushToken();

  Future<void> fetchNativeUpdate() => sync.fetchNativeUpdate();
}

/// Provider for the settings repository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => const SettingsRepository(),
);
