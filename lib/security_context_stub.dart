// Stub SecurityContext for web, where dart:io is unavailable.
import 'dart:typed_data';

class SecurityContext {
  SecurityContext._();

  static final SecurityContext defaultContext = SecurityContext._();

  // ignore: avoid_unused_parameters
  void setTrustedCertificatesBytes(Uint8List bytes) {}
}
