import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

export 'package:local_auth/local_auth.dart' show BiometricType;

/// Result of a biometric authentication attempt.
enum BiometricAuthResult {
  /// Authentication succeeded.
  authenticated,

  /// User cancelled the prompt.
  cancelled,

  /// No biometrics enrolled on this device.
  notEnrolled,

  /// Biometric hardware not available.
  notAvailable,

  /// Authentication failed (wrong finger, face not recognized, etc.).
  failed,

  /// Locked out after too many failed attempts.
  lockedOut,

  /// Permanently locked out (requires device passcode to reset).
  permanentlyLockedOut,

  /// Passcode not set on the device.
  passcodeNotSet,

  /// An unexpected error occurred.
  error,
}

/// Service for biometric authentication (Face ID, Touch ID, fingerprint).
///
/// Wraps `local_auth` with a clean, platform-neutral API.
///
/// ## Usage
/// ```dart
/// final biometric = BiometricService();
/// final canAuth = await biometric.canAuthenticate;
/// if (canAuth) {
///   final result = await biometric.authenticate(
///     reason: 'Verify your identity to access this feature',
///   );
///   if (result == BiometricAuthResult.authenticated) { ... }
/// }
/// ```
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether biometric authentication can be attempted on this device.
  ///
  /// Returns `true` if the device has biometric hardware and at least
  /// one biometric is enrolled.
  Future<bool> get canAuthenticate async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('[BiometricService] canCheckBiometrics error: $e');
      return false;
    }
  }

  /// The list of biometric types available on this device.
  ///
  /// Empty if no biometrics are enrolled or hardware is unavailable.
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Whether any biometric is currently enrolled.
  Future<bool> get hasEnrolledBiometrics async {
    final types = await availableBiometrics;
    return types.isNotEmpty;
  }

  /// Authenticates the user using biometrics.
  ///
  /// [reason] — the message shown to the user in the authentication prompt.
  ///   Should be short and clearly explain why authentication is needed.
  ///
  /// [options] — additional authentication options.
  ///
  /// Returns a [BiometricAuthResult] indicating the outcome.
  Future<BiometricAuthResult> authenticate({
    required String reason,
    BiometricAuthOptions? options,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: options?._toOptions() ?? const AuthenticationOptions(),
      );
      return ok
          ? BiometricAuthResult.authenticated
          : BiometricAuthResult.failed;
    } on PlatformException catch (e) {
      return _mapPlatformException(e);
    } catch (e) {
      debugPrint('[BiometricService] authenticate unexpected error: $e');
      return BiometricAuthResult.error;
    }
  }

  /// Cancels any in-progress authentication.
  ///
  /// On iOS this stops the Face ID / Touch ID prompt.
  /// On Android this has no effect if the system dialog is already shown.
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      debugPrint('[BiometricService] stopAuthentication error: $e');
    }
  }

  BiometricAuthResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotEnrolled':
        return BiometricAuthResult.notEnrolled;
      case 'LockedOut':
        return BiometricAuthResult.lockedOut;
      case 'PermanentlyLockedOut':
        return BiometricAuthResult.permanentlyLockedOut;
      case 'PasscodeNotSet':
        return BiometricAuthResult.passcodeNotSet;
      case 'NotAvailable':
        return BiometricAuthResult.notAvailable;
      case 'NotPaired':
      case 'Failed':
        return BiometricAuthResult.failed;
      default:
        return BiometricAuthResult.error;
    }
  }
}

/// Options for [BiometricService.authenticate].
class BiometricAuthOptions {
  const BiometricAuthOptions({
    this.sticky = false,
    this.biometricOnly = false,
  });

  /// If `true`, the system back button and screen dimming are disabled
  /// during authentication. Use with caution — users cannot cancel.
  final bool sticky;

  /// If `true`, only biometrics are offered; device PIN/passcode is not shown.
  /// Falls back to [BiometricAuthResult.notEnrolled] if biometrics are
  /// not enrolled.
  final bool biometricOnly;

  AuthenticationOptions _toOptions() => AuthenticationOptions(
        stickyAuth: sticky,
        biometricOnly: biometricOnly,
      );
}
