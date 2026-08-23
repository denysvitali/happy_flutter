import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../encryption/message_processor.dart';
import 'failure_telemetry.dart';

/// Rows processed per inline chunk before yielding to the event loop.
///
/// On web (no isolate support) and for sub-isolate-threshold batches,
/// processing runs on the main thread. Chunked with a
/// `Future.delayed(Duration.zero)` between chunks — the same pattern as
/// CryptoSecretBox.decryptBatchInIsolate's per-item yields — so a long
/// page cannot hold the frame hostage.
const int _inlineChunkSize = 8;

Future<ProcessedMessages> processDecryptedMessagesWithIsolation({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  required List<bool> wasEncrypted,
  required bool useIsolate,
}) async {
  // Isolates are not supported on web — use main-thread processing,
  // chunked so the UI can render between chunks.
  if (!useIsolate || kIsWeb) {
    return _counted(
      await _processInlineChunked(
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

/// Inline counterpart of [processDecryptedMessages] that processes
/// [_inlineChunkSize] rows per event-loop turn and merges the chunk
/// results in order.
///
/// Merged fields match a single whole-batch call exactly: messages,
/// toolResults, usageUpdates, and droppedReasons concatenate in input
/// order, maxSeq is the max across chunks, and
/// undecryptableRenderedCount sums. The one difference is the scope of
/// the within-batch fatal-error-card dedupe (`emittedErrorKeys` inside
/// [processDecryptedMessages]): it spans a chunk instead of the whole
/// batch, so an identical error card straddling a chunk boundary can
/// render twice.
Future<ProcessedMessages> _processInlineChunked({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  required List<bool> wasEncrypted,
}) async {
  final messages = <Map<String, dynamic>>[];
  final toolResults = <Map<String, dynamic>>[];
  final usageUpdates = <Map<String, dynamic>>[];
  final droppedReasons = <String>[];
  var maxSeq = -1;
  var undecryptableRenderedCount = 0;

  for (var start = 0; start < wireMessages.length; start += _inlineChunkSize) {
    var end = start + _inlineChunkSize;
    if (end > wireMessages.length) end = wireMessages.length;
    if (start > 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final result = processDecryptedMessages(
      decryptedJsonList: decryptedJsonList.sublist(start, end),
      wireMessages: wireMessages.sublist(start, end),
      sessionId: sessionId,
      wasEncrypted: wasEncrypted.sublist(start, end),
    );
    messages.addAll(result.messages);
    toolResults.addAll(result.toolResults);
    usageUpdates.addAll(result.usageUpdates);
    droppedReasons.addAll(result.droppedReasons);
    if (result.maxSeq > maxSeq) maxSeq = result.maxSeq;
    undecryptableRenderedCount += result.undecryptableRenderedCount;
  }

  return ProcessedMessages(
    messages: messages,
    toolResults: toolResults,
    usageUpdates: usageUpdates,
    maxSeq: maxSeq,
    droppedReasons: droppedReasons,
    undecryptableRenderedCount: undecryptableRenderedCount,
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
