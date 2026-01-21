import 'package:flutter/foundation.dart';

/// Simple certificate provider placeholder
class CertificateProvider {
  static final CertificateProvider _instance = CertificateProvider._();
  factory CertificateProvider() => _instance;
  CertificateProvider._();

  Future<List<Uint8List>?> getUserCertificates() async {
    return null; // User CAs not supported on this platform
  }

  Future<bool> hasUserCertificates() async {
    return false;
  }

  Future<Uint8List?> getCertificatesBytes() async {
    return null;
  }
}
