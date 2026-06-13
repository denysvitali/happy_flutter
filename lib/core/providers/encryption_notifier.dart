import 'package:riverpod/riverpod.dart';

import '../services/sync_service.dart';

/// Encapsulates encryption cache operations so screens don't call sync directly.
class EncryptionNotifier extends Notifier<void> {
  @override
  void build() {}

  void clearAllCaches() {
    if (!sync.isInitialized) return;
    sync.encryption.clearAllCaches();
  }
}

final encryptionNotifierProvider = NotifierProvider<EncryptionNotifier, void>(
  () => EncryptionNotifier(),
);
