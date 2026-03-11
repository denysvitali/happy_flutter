import 'dart:async';

import 'api_client.dart';
import 'base_api_exception.dart';

/// Messages API client
/// Provides message operations for sessions
/// Based on React Native's apiMessages.ts
class MessagesApi {
  MessagesApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Fetch messages for a session with pagination
  Future<MessagesResponse> fetchMessages(
    String sessionId, {
    required int afterSeq,
    int limit = 100,
  }) async {
    final response = await _client.get(
      '/v3/sessions/$sessionId/messages',
      queryParameters: {'after_seq': afterSeq, 'limit': limit},
    );

    if (!_client.isSuccess(response)) {
      throw MessagesApiException(
        'Failed to fetch messages: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final messages = (data['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final hasMore = data['hasMore'] as bool? ?? false;

    return MessagesResponse(
      messages: messages,
      hasMore: hasMore,
    );
  }

  /// Send a message to a session
  Future<SendMessageResponse> sendMessage(
    String sessionId, {
    required String encryptedContent,
    String? localId,
  }) async {
    final response = await _client.post(
      '/v3/sessions/$sessionId/messages',
      data: {
        'messages': [
          {
            'content': encryptedContent,
            'localId': ?localId,
          },
        ],
      },
    );

    if (!_client.isSuccess(response)) {
      throw MessagesApiException(
        'Failed to send message: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (serverMessages.isNotEmpty) {
      final serverMsg = serverMessages.first;
      return SendMessageResponse(
        id: serverMsg['id'] as String,
        seq: serverMsg['seq'] as int,
        createdAt: serverMsg['createdAt'] as int,
        localId: serverMsg['localId'] as String?,
      );
    }

    throw const MessagesApiException('No message returned from server');
  }

  /// Send multiple messages in a batch
  Future<List<SendMessageResponse>> sendMessagesBatch(
    String sessionId, {
    required List<SendMessageRequest> messages,
  }) async {
    if (messages.isEmpty) {
      return [];
    }

    final response = await _client.post(
      '/v3/sessions/$sessionId/messages',
      data: {
        'messages': messages
            .map((m) => {
                  'content': m.encryptedContent,
                  if (m.localId != null) 'localId': m.localId,
                })
            .toList(),
      },
    );

    if (!_client.isSuccess(response)) {
      throw MessagesApiException(
        'Failed to send messages: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return serverMessages.map((serverMsg) {
      return SendMessageResponse(
        id: serverMsg['id'] as String,
        seq: serverMsg['seq'] as int,
        createdAt: serverMsg['createdAt'] as int,
        localId: serverMsg['localId'] as String?,
      );
    }).toList();
  }
}

/// Exception thrown by Messages API operations
class MessagesApiException extends BaseApiException {
  const MessagesApiException(super.message, {super.statusCode});

  @override
  String toString() => 'MessagesApiException: $message';
}

/// Response from fetching messages
class MessagesResponse {
  const MessagesResponse({
    required this.messages,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> messages;
  final bool hasMore;
}

/// Request to send a message
class SendMessageRequest {
  const SendMessageRequest({
    required this.encryptedContent,
    this.localId,
  });

  final String encryptedContent;
  final String? localId;
}

/// Response from sending a message
class SendMessageResponse {
  const SendMessageResponse({
    required this.id,
    required this.seq,
    required this.createdAt,
    this.localId,
  });

  final String id;
  final int seq;
  final int createdAt;
  final String? localId;
}
