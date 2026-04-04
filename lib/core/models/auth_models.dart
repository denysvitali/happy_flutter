import 'dart:convert';
import 'dart:typed_data';

/// Result of initiating a device linking flow.
class DeviceLinkingResult {
  DeviceLinkingResult({
    required this.linkingId,
    required this.publicKey,
    required this.secret,
  });

  final String linkingId;
  final Uint8List publicKey;
  final Uint8List secret;

  /// Get the QR code data for this linking.
  /// Format: `happy:///account?<base64url_public_key>`
  String getQRData() {
    final base64Key = base64Encode(publicKey);
    final base64UrlKey = base64Key
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
    return 'happy:///account?$base64UrlKey';
  }
}
