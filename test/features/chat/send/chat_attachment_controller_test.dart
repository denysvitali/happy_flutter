import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/features/chat/send/chat_attachment_controller.dart';

OutgoingImage _img(String data) =>
    OutgoingImage(mediaType: 'image/jpeg', base64Data: data);

void main() {
  group('ChatAttachmentController', () {
    test('add appends and notifies listeners', () {
      final controller = ChatAttachmentController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.add(_img('a')), isTrue);

      expect(controller.images, hasLength(1));
      expect(notifications, 1);
    });

    test('add returns false without notifying at the cap', () {
      final controller = ChatAttachmentController();
      for (var i = 0; i < ChatAttachmentController.maxAttachments; i++) {
        expect(controller.add(_img('img$i')), isTrue);
      }
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.add(_img('overflow')), isFalse);
      expect(controller.images, hasLength(
        ChatAttachmentController.maxAttachments,
      ));
      expect(notifications, 0);
    });

    test('remove deletes the exact instance, not a positional slot', () {
      final controller = ChatAttachmentController();
      final first = _img('first');
      final second = _img('second');
      final third = _img('third');
      controller
        ..add(first)
        ..add(second)
        ..add(third);

      expect(controller.remove(second), isTrue);

      expect(controller.images, orderedEquals([first, third]));
    });

    test('remove is a no-op for an instance that was never staged', () {
      final controller = ChatAttachmentController();
      controller.add(_img('staged'));
      var notifications = 0;
      controller.addListener(() => notifications++);

      // Simulates a stale onRemove callback captured by an old frame.
      expect(controller.remove(_img('staged')), isFalse);
      expect(controller.images, hasLength(1));
      expect(notifications, 0);
    });

    test('remove after clear is a safe no-op', () {
      final controller = ChatAttachmentController();
      final image = _img('gone');
      controller.add(image);
      controller.clear();

      expect(controller.remove(image), isFalse);
      expect(controller.isEmpty, isTrue);
    });

    test('clear notifies only when non-empty', () {
      final controller = ChatAttachmentController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.clear();
      expect(notifications, 0);

      controller.add(_img('x'));
      controller.clear();
      expect(notifications, 2); // add + clear
      expect(controller.isEmpty, isTrue);
    });
  });
}
