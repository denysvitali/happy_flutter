import 'package:flutter/services.dart';

import '../services/logger_service.dart' show logger;

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
  int maxCharacters = 256 * 1024,
}) async {
  final originalCharacters = text.length;
  final truncated = originalCharacters > maxCharacters;
  final clipboardText = truncated
      ? _truncateForClipboard(text, maxCharacters)
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

String _truncateForClipboard(String text, int maxCharacters) {
  const suffix = '\n\n[truncated for clipboard]';
  if (maxCharacters <= suffix.length) {
    return text.substring(0, maxCharacters);
  }
  return text.substring(0, maxCharacters - suffix.length) + suffix;
}
