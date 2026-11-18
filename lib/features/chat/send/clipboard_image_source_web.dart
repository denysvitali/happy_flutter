import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../../core/services/logger_service.dart' show logger;

/// The browser owns Ctrl+V on the web; see [listenForPastedImages].
bool get supportsKeyboardImagePaste => false;

Future<Uint8List?> readClipboardImage() async => null;

/// Calls [onImage] for each image file in a `paste` event while [isTarget]
/// holds. Pastes that carry text are left to the browser, so copying a
/// spreadsheet cell (text plus a rendered bitmap) still pastes text.
VoidCallback listenForPastedImages(
  bool Function() isTarget,
  void Function(Uint8List bytes) onImage,
) {
  void handle(web.ClipboardEvent event) {
    if (!isTarget()) return;
    final data = event.clipboardData;
    if (data == null || data.getData('text/plain').isNotEmpty) return;
    final images = <web.File>[];
    for (var i = 0; i < data.files.length; i++) {
      final file = data.files.item(i);
      if (file != null && file.type.startsWith('image/')) images.add(file);
    }
    if (images.isEmpty) return;
    event.preventDefault();
    for (final file in images) {
      file.arrayBuffer().toDart.then(
        (buffer) => onImage(buffer.toDart.asUint8List()),
        onError: (Object e) => logger.warning('[ClipboardImage] read: $e'),
      );
    }
  }

  final listener = handle.toJS;
  web.document.addEventListener('paste', listener);
  return () => web.document.removeEventListener('paste', listener);
}
