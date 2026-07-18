import 'package:flutter/foundation.dart';

import '../../../core/models/outgoing_image.dart';

/// Holds the images currently staged in the composer.
///
/// Owned by the chat screen (like the `TextEditingController`) so the
/// send action can read and clear the staged attachments; [ChatInput]
/// mutates it via the attach button and preview strip. The list is
/// cleared by the screen once the message is handed to the send path —
/// attachments are single-use, mirroring how the text field clears.
class ChatAttachmentController extends ChangeNotifier {
  /// Hard cap on staged attachments per message — keeps the encrypted
  /// payload well under the 16MiB socket frame cap.
  static const int maxAttachments = 4;

  final List<OutgoingImage> _images = [];

  List<OutgoingImage> get images => List.unmodifiable(_images);

  bool get isEmpty => _images.isEmpty;
  bool get isNotEmpty => _images.isNotEmpty;

  /// Returns false (without notifying) when the cap is already reached.
  bool add(OutgoingImage image) {
    if (_images.length >= maxAttachments) return false;
    _images.add(image);
    notifyListeners();
    return true;
  }

  /// Removes [image] by identity. Returns false when it is no longer
  /// staged (already removed, or the controller was cleared after a send)
  /// so a remove callback captured by an old frame is a safe no-op
  /// instead of an out-of-range throw or a removal of the wrong item.
  bool remove(OutgoingImage image) {
    final index = _images.indexWhere(
      (candidate) => identical(candidate, image),
    );
    if (index < 0) return false;
    _images.removeAt(index);
    notifyListeners();
    return true;
  }

  void clear() {
    if (_images.isEmpty) return;
    _images.clear();
    notifyListeners();
  }
}
