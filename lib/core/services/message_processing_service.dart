import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../encryption/message_processor.dart';
import 'failure_telemetry.dart';

Future<ProcessedMessages> processDecryptedMessagesWithIsolation({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  required List<bool> wasEncrypted,
  required bool useIsolate,
}) async {
  // Isolates are not supported on web — use main-thread processing.
  if (!useIsolate || kIsWeb) {
    return _counted(
      processDecryptedMessages(
        decryptedJsonList: decryptedJsonList,
        wireMessages: wireMessages,
        sessionId: sessionId,
        wasEncrypted: wasEncrypted,
      ),
    );
  }

  return _counted(
    await Isolate.run(() {
      return processDecryptedMessages(
        decryptedJsonList: decryptedJsonList,
        wireMessages: wireMessages,
        sessionId: sessionId,
        wasEncrypted: wasEncrypted,
      );
    }),
  );
}

/// Emit `app.messages.undecryptable_rendered` for [result] and pass it
/// through unchanged.
///
/// Counted here rather than inside `processDecryptedMessages` because that
/// function also runs inside `Isolate.run`, where the OTel singleton is
/// uninitialised and the counter add would be silently dropped.  Emitted
/// once per batch with the batch total, so a 500-message page whose key
/// rotated costs one counter add, not 500.
ProcessedMessages _counted(ProcessedMessages result) {
  recordUndecryptableRendered(
    // Constant, matching the `errorType` the error bubble is built with.
    // Kept as an attribute so a future second bubble kind can be
    // distinguished without minting a new metric.
    errorType: 'decryption_failed',
    count: result.undecryptableRenderedCount,
  );
  return result;
}
