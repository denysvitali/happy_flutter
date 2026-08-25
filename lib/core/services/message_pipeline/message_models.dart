part of '../sync_service.dart';

enum MessagePipelineSource {
  socket,
  http,
}

enum MessagePipelineStage {
  raw,
  normalized,
  processed,
  merged,
  grouped,
  notified,
}

class MessageIngressEvent {
  MessageIngressEvent({
    required this.source,
    required this.sessionId,
    required this.rawPayload,
    this.traceId,
    this.metadata = const {},
    this.isVisibleSession = false,
    this.notifySessionsDomain = false,
  });

  final MessagePipelineSource source;
  final String sessionId;
  final dynamic rawPayload;
  final String? traceId;
  final Map<String, dynamic> metadata;
  final bool isVisibleSession;
  final bool notifySessionsDomain;
}

class NormalizedMessageBatch {
  NormalizedMessageBatch({
    required this.source,
    required this.sessionId,
    required this.messages,
    required this.traceId,
    this.metadata = const {},
    this.afterSeq,
  });

  final MessagePipelineSource source;
  final String sessionId;
  final List<Map<String, dynamic>> messages;
  final String traceId;
  final Map<String, dynamic> metadata;
  final int? afterSeq;
}

class ProcessedMessageBundle {
  ProcessedMessageBundle({
    required this.messages,
    required this.toolResults,
    required this.usageUpdates,
    required this.maxSeq,
    required this.droppedReasons,
    required this.hasSidechain,
    required this.traceId,
    this.source,
    this.errorMessage,
  });

  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> toolResults;
  final List<Map<String, dynamic>> usageUpdates;
  final int maxSeq;
  final List<String> droppedReasons;
  final bool hasSidechain;
  final String traceId;
  final MessagePipelineSource? source;
  final String? errorMessage;

  /// Rows in the post-decrypt mutation tail. Above this size, the
  /// orchestrator exposes a frame boundary between phases so sustained
  /// streaming cannot hold the UI isolate through the entire merge.
  static const int postDecryptMutationYieldRows = 120;
}

class FetchResponseBatch {
  FetchResponseBatch({
    required this.sessionId,
    required this.rawMessages,
    required this.traceId,
    required this.isVisibleSession,
    this.page = 0,
    this.afterSeq = 0,
    this.notifyVisibleOnly = false,
  });

  final String sessionId;
  final List<Map<String, dynamic>> rawMessages;
  final String traceId;
  final bool isVisibleSession;
  final int page;
  final int afterSeq;
  final bool notifyVisibleOnly;
}
