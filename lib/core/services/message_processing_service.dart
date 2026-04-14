import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../encryption/message_processor.dart';

Future<ProcessedMessages> processDecryptedMessagesWithIsolation({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  required List<bool> wasEncrypted,
  required bool useIsolate,
}) async {
  // Isolates are not supported on web — use main-thread processing.
  if (!useIsolate || kIsWeb) {
    return processDecryptedMessages(
      decryptedJsonList: decryptedJsonList,
      wireMessages: wireMessages,
      sessionId: sessionId,
      wasEncrypted: wasEncrypted,
    );
  }

  return Isolate.run(() {
    return processDecryptedMessages(
      decryptedJsonList: decryptedJsonList,
      wireMessages: wireMessages,
      sessionId: sessionId,
      wasEncrypted: wasEncrypted,
    );
  });
}
