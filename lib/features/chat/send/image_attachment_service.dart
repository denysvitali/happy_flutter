import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/models/outgoing_image.dart';
import '../../../core/services/logger_service.dart' show logger;

/// Normalized image ready for attachment: guaranteed JPEG or PNG within
/// the API's per-image size budget.
typedef NormalizedImage = ({
  Uint8List bytes,
  String mediaType,
  int? width,
  int? height,
});

/// Detects the media type of raw image bytes from magic numbers.
///
/// Returns `image/jpeg`, `image/png`, `image/gif`, `image/webp`, or null
/// when the bytes match no known signature.
String? detectImageMediaType(Uint8List bytes) {
  if (bytes.length < 12) return null;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  // GIF: "GIF8"
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'image/gif';
  }
  // WebP: "RIFF"...."WEBP"
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Normalizes picked image bytes for the Anthropic API.
///
/// The Claude API accepts JPEG/PNG/GIF/WebP sources, but the daemon →
/// Claude Code stdin path is only verified for JPEG/PNG, and animated or
/// exotic formats waste tokens — so anything that is not already JPEG or
/// PNG is transcoded to JPEG (first frame for animations). Images larger
/// than [maxDimension] on the long edge are downscaled, which is also the
/// API's token-optimal upper bound (~1.15 megapixels).
///
/// Returns null when the bytes cannot be decoded at all.
NormalizedImage? normalizeImageBytes(
  Uint8List bytes, {
  int maxDimension = 1568,
  int jpegQuality = 88,
}) {
  final mediaType = detectImageMediaType(bytes);
  if (mediaType == null) return null;

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    logger.warning('[ImageAttachment] decode failed: $e');
    return null;
  }
  if (decoded == null) return null;

  final needsResize =
      decoded.width > maxDimension || decoded.height > maxDimension;
  final resized = needsResize
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
        )
      : decoded;

  // Already-acceptable formats pass through untouched when no resize was
  // needed — avoids a re-encode quality loss for JPEG screenshots/photos.
  if (!needsResize && (mediaType == 'image/jpeg' || mediaType == 'image/png')) {
    return (
      bytes: bytes,
      mediaType: mediaType,
      width: decoded.width,
      height: decoded.height,
    );
  }

  final encoded = Uint8List.fromList(
    img.encodeJpg(resized, quality: jpegQuality),
  );
  return (
    bytes: encoded,
    mediaType: 'image/jpeg',
    width: resized.width,
    height: resized.height,
  );
}

/// Top-level worker for [compute] so decode/resize/encode never runs on
/// the UI isolate. Takes and returns only sendable POD across the isolate
/// boundary; `normalizeImageBytes` already swallows decode errors, so the
/// catch-all here covers encode/resize failures (e.g. OOM on pathological
/// input) and surfaces them as a plain null.
NormalizedImage? _normalizeImageWorker((Uint8List, int, int) args) {
  try {
    return normalizeImageBytes(
      args.$1,
      maxDimension: args.$2,
      jpegQuality: args.$3,
    );
  } catch (_) {
    return null;
  }
}

/// Picks images from the gallery or camera and normalizes them into
/// [OutgoingImage]s suitable for inlining into a chat message.
class ImageAttachmentService {
  ImageAttachmentService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long-edge pixel cap handed to the platform picker. The API resizes
  /// anything above ~1568px anyway, so sending more just burns upload
  /// bytes and socket payload.
  static const int maxImageDimension = 1568;

  /// JPEG quality for both the platform picker's pre-scale and the
  /// transcode-to-JPEG path in [normalizeImageBytes].
  static const int jpegQuality = 88;

  /// Hard cap on the base64 payload of a single image. The API rejects
  /// images above 5MB (bytes); base64 inflates by 4/3, so 3.4M chars
  /// keeps us comfortably below both the API limit and the 16MiB socket
  /// frame cap even with several images per message.
  static const int maxBase64Length = 3400000;

  Future<OutgoingImage?> pickFromGallery() =>
      _pickAndNormalize(ImageSource.gallery);

  Future<OutgoingImage?> pickFromCamera() =>
      _pickAndNormalize(ImageSource.camera);

  Future<OutgoingImage?> _pickAndNormalize(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: maxImageDimension.toDouble(),
        maxHeight: maxImageDimension.toDouble(),
        imageQuality: jpegQuality,
      );
    } catch (e) {
      logger.warning('[ImageAttachment] pickImage($source) failed: $e');
      return null;
    }
    if (file == null) return null; // user cancelled

    // Everything past the picker is one guarded unit: a read failure
    // (file vanished), a codec crash, or a base64 blowup must surface as
    // "no attachment", never as an uncaught async error from the tap.
    try {
      final bytes = await file.readAsBytes();
      final normalized = await compute(
        _normalizeImageWorker,
        (bytes, maxImageDimension, jpegQuality),
      );
      if (normalized == null) {
        logger.warning(
          '[ImageAttachment] unsupported image bytes from ${file.path}',
        );
        return null;
      }

      final base64Data = base64Encode(normalized.bytes);
      if (base64Data.length > maxBase64Length) {
        logger.warning(
          '[ImageAttachment] image too large after normalize: '
          '${base64Data.length} base64 chars — dropping',
        );
        return null;
      }

      return OutgoingImage(
        mediaType: normalized.mediaType,
        base64Data: base64Data,
        width: normalized.width,
        height: normalized.height,
      );
    } catch (e) {
      logger.warning(
        '[ImageAttachment] failed to read/normalize ${file.path}: $e',
      );
      return null;
    }
  }
}
