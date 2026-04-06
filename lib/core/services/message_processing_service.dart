import 'dart:isolate';

import '../encryption/message_processor.dart';

Future<ProcessedMessages> processDecryptedMessagesWithIsolation({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  required List<bool> wasEncrypted,
  required bool useIsolate,
}) async {
  if (!useIsolate) {
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
