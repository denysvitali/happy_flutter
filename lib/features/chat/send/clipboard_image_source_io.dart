import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../core/services/logger_service.dart' show logger;

/// Whether Ctrl/Cmd+V in the composer should look for a clipboard image.
bool get supportsKeyboardImagePaste =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

/// Reads the clipboard image, or null when there is none or it is unreadable.
Future<Uint8List?> readClipboardImage() async {
  if (!supportsKeyboardImagePaste) return null;
  try {
    final bytes = await Pasteboard.image;
    return bytes == null || bytes.isEmpty ? null : bytes;
  } catch (e) {
    logger.warning('[ClipboardImage] read failed: $e');
    return null;
  }
}

/// No DOM paste events outside the web; returns a no-op disposer.
VoidCallback listenForPastedImages(
  bool Function() isTarget,
  void Function(Uint8List bytes) onImage,
) => () {};
