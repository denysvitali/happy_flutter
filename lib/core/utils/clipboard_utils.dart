import 'dart:convert';

import 'package:flutter/services.dart';

import '../services/logger_service.dart' show logger;

const int defaultClipboardMaxBytes = 128 * 1024;

class ClipboardWriteResult {
  const ClipboardWriteResult({
    required this.success,
    required this.truncated,
    required this.charactersCopied,
    required this.originalCharacters,
    this.error,
  });

  final bool success;
  final bool truncated;
  final int charactersCopied;
  final int originalCharacters;
  final Object? error;
}

Future<ClipboardWriteResult> setClipboardTextSafely(
  String text, {
  int maxBytes = defaultClipboardMaxBytes,
}) async {
  final originalCharacters = text.length;
  final originalBytes = utf8.encode(text).length;
  final truncated = originalBytes > maxBytes;
  final clipboardText = truncated
      ? _truncateForClipboard(text, maxBytes)
      : text;
  try {
    await Clipboard.setData(ClipboardData(text: clipboardText));
    return ClipboardWriteResult(
      success: true,
      truncated: truncated,
      charactersCopied: clipboardText.length,
      originalCharacters: originalCharacters,
    );
  } on PlatformException catch (error, stackTrace) {
    logger.warning('Clipboard write failed', error, stackTrace);
    return ClipboardWriteResult(
      success: false,
      truncated: truncated,
      charactersCopied: 0,
      originalCharacters: originalCharacters,
      error: error,
    );
  }
}

String _truncateForClipboard(String text, int maxBytes) {
  const suffix = '\n\n[truncated for clipboard]';
  if (maxBytes <= 0) {
    return '';
  }
  if (utf8.encode(text).length <= maxBytes) {
    return text;
  }

  final suffixBytes = utf8.encode(suffix).length;
  if (maxBytes <= suffixBytes) {
    return _truncateToUtf8Bytes(text, maxBytes);
  }

  return _truncateToUtf8Bytes(text, maxBytes - suffixBytes) + suffix;
}

String _truncateToUtf8Bytes(String text, int maxBytes) {
  final buffer = StringBuffer();
  var bytesUsed = 0;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    final characterBytes = utf8.encode(character).length;
    if (bytesUsed + characterBytes > maxBytes) {
      break;
    }
    buffer.write(character);
    bytesUsed += characterBytes;
  }
  return buffer.toString();
}
