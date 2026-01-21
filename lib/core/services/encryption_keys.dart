/// Simple key storage placeholder
class EncryptionKeys {
  static final EncryptionKeys _instance = EncryptionKeys._();
  factory EncryptionKeys() => _instance;
  EncryptionKeys._();

  final _sessionKeys = <String, Uint8List?>{};
  final _machineKeys = <String, Uint8List?>{};

  void setSessionKey(String sessionId, Uint8List? key) {
    _sessionKeys[sessionId] = key;
  }

  Uint8List? getSessionKey(String sessionId) {
    return _sessionKeys[sessionId];
  }

  void removeSessionKey(String sessionId) {
    _sessionKeys.remove(sessionId);
  }

  void setMachineKey(String machineId, Uint8List? key) {
    _machineKeys[machineId] = key;
  }

  Uint8List? getMachineKey(String machineId) {
    return _machineKeys[machineId];
  }

  void clearSessionKeys() {
    _sessionKeys.clear();
  }

  void clearMachineKeys() {
    _machineKeys.clear();
  }
}
