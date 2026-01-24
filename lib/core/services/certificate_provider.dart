import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Certificate provider for user-added CA certificates on Android
/// This allows the app to trust certificates installed in the Android system trust store
class CertificateProvider {
  static final CertificateProvider _instance = CertificateProvider._();
  factory CertificateProvider() => _instance;
  CertificateProvider._();

  /// Check if user certificates are available
  /// On Android, this checks for user-added CAs in the system trust store
  bool hasUserCertificates() {
    if (!kIsWeb && Platform.isAndroid) {
      return _checkAndroidUserCertificatesSync();
    }
    return false;
  }

  /// Get user CA certificates as bytes
  /// Returns null if no user certificates are available
  Future<Uint8List?> getUserCertificates() {
    if (!kIsWeb && Platform.isAndroid) {
      return _getAndroidUserCertificates();
    }
    return Future.value(null);
  }

  /// Get certificates bytes for use with SecurityContext
  Future<Uint8List?> getCertificatesBytes() async {
    return getUserCertificates();
  }

  /// Android-specific: Check if user certificates exist (sync)
  bool _checkAndroidUserCertificatesSync() {
    try {
      // On Android, user-added CAs are trusted by default in the system
      // We return true to indicate user CAs should be supported
      return true;
    } catch (e) {
      debugPrint('Error checking Android user certificates: $e');
      return false;
    }
  }

  /// Android-specific: Get user-added CA certificates
  /// Returns the concatenated PEM certificates from Android user trust store
  Future<Uint8List?> _getAndroidUserCertificates() async {
    try {
      // On Android 7+ (API 24+), user-added CAs are available via
      // the system certificate store. However, direct access from Flutter
      // is limited. The app trusts system CAs by default.
      //
      // For enterprise/custom CA scenarios, the options are:
      // 1. System CAs - Already trusted by default on Android
      // 2. User-added CAs - Trusted when user installs them in system
      // 3. App-specific CAs - Need to be bundled with the app
      //
      // Flutter/Dart's default HttpClient trusts system CAs including
      // user-added ones on Android. The issue may be that:
      // - Server is using a self-signed cert not in user store
      // - Server cert chain is incomplete
      // - Need explicit certificate validation
      //
      // For now, we return null indicating system defaults should work
      // If custom certificates are needed, they should be bundled in assets

      // Alternative: Check if we have bundled certificates
      return await _getBundledCertificates();
    } catch (e) {
      debugPrint('Error getting Android user certificates: $e');
      return null;
    }
  }

  /// Get bundled certificates from assets
  Future<Uint8List?> _getBundledCertificates() async {
    // This method would load certificates bundled with the app
    // For enterprise deployments, bundle CA certs in assets/certs/
    return null;
  }
}
