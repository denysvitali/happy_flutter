import 'package:package_info_plus/package_info_plus.dart';

/// Cached accessor for [PackageInfo.fromPlatform].
///
/// The underlying platform-channel call costs ~20–100ms on cold start.
/// Multiple callers (OpenTelemetry init, changelog check, developer screen)
/// hit it during startup; this cache returns a single shared future so the
/// platform handshake happens at most once.
class PackageInfoCache {
  PackageInfoCache._();

  static Future<PackageInfo>? _cached;

  static Future<PackageInfo> get() {
    return _cached ??= PackageInfo.fromPlatform();
  }
}
