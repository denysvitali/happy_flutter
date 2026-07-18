import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/send/image_attachment_service.dart';
import 'package:image/image.dart' as img;

Uint8List _png(int width, int height) => Uint8List.fromList(
  img.encodePng(img.Image(width: width, height: height)),
);

void main() {
  group('detectImageMediaType', () {
    test('detects jpeg, png, gif, and webp magic numbers', () {
      expect(
        detectImageMediaType(
          Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4))),
        ),
        'image/jpeg',
      );
      expect(detectImageMediaType(_png(4, 4)), 'image/png');
      expect(
        detectImageMediaType(
          Uint8List.fromList(img.encodeGif(img.Image(width: 4, height: 4))),
        ),
        'image/gif',
      );
      expect(
        detectImageMediaType(
          Uint8List.fromList(const [
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0, 0, 0, 0,
            0x57, 0x45, 0x42, 0x50, // "WEBP"
            0, 0, 0, 0,
          ]),
        ),
        'image/webp',
      );
    });

    test('returns null for short or unknown byte sequences', () {
      expect(detectImageMediaType(Uint8List(0)), isNull);
      expect(detectImageMediaType(Uint8List(8)), isNull);
      expect(
        detectImageMediaType(Uint8List.fromList(List.filled(16, 0x42))),
        isNull,
      );
    });
  });

  group('normalizeImageBytes', () {
    test('passes a small png through untouched (no re-encode)', () {
      final bytes = _png(64, 32);

      final result = normalizeImageBytes(bytes);

      expect(result, isNotNull);
      expect(result!.mediaType, 'image/png');
      expect(result.bytes, same(bytes));
      expect(result.width, 64);
      expect(result.height, 32);
    });

    test('transcodes gif to jpeg', () {
      final gif = Uint8List.fromList(
        img.encodeGif(img.Image(width: 16, height: 16)),
      );

      final result = normalizeImageBytes(gif);

      expect(result, isNotNull);
      expect(result!.mediaType, 'image/jpeg');
      expect(detectImageMediaType(result.bytes), 'image/jpeg');
    });

    test('downscales images beyond maxDimension on the long edge', () {
      final big = _png(3000, 2000);

      final result = normalizeImageBytes(big);

      expect(result, isNotNull);
      expect(result!.width, ImageAttachmentService.maxImageDimension);
      expect(result.height, lessThan(2000));
      expect(result.mediaType, 'image/jpeg');
    });

    test('returns null for undecodable bytes with a valid magic', () {
      final garbage = Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, // PNG magic, then junk
        1, 2, 3, 4, 5, 6, 7, 8,
      ]);

      expect(normalizeImageBytes(garbage), isNull);
    });

    test('returns null for bytes with no known signature', () {
      expect(
        normalizeImageBytes(Uint8List.fromList(List.filled(64, 0x42))),
        isNull,
      );
    });
  });
}
