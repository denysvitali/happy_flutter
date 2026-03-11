import 'dart:async';

import 'package:dio/dio.dart';

import '../services/logger_service.dart' show logger;
import 'api_client.dart';
import 'base_api_exception.dart';

/// Sessions API client
/// Provides session management operations
/// Based on React Native's apiSessions.ts
class SessionsApi {
  SessionsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  bool _isSuccess(Response<dynamic> response) {
    final statusCode = response.statusCode;
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  /// Fetch sessions with optional pagination and delta sync
  /// Returns a list of session data maps (encrypted)
  Future<List<dynamic>> fetchSessions({
    int limit = 50,
    String? cursor,
    int? changedSince,
  }) async {
    return _fetchSessionsV2(
      limit: limit,
      cursor: cursor,
      changedSince: changedSince,
    );
  }

  Future<List<dynamic>> _fetchSessionsV2({
    required int limit,
    String? cursor,
    int? changedSince,
  }) async {
    final allSessions = <dynamic>[];
    var nextCursor = cursor;

    while (true) {
      final response = await _client.get(
        '/v2/sessions',
        queryParameters: {
          'limit': limit,
          'cursor': ?nextCursor,
          'changedSince': ?changedSince,
        },
      );

      if (!_isSuccess(response)) {
        logger.warning(
          'fetchSessions API error: '
          'status=${response.statusCode} '
          'body=${response.data}',
        );
        throw SessionsApiException(
          'Failed to fetch sessions: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final page = data['sessions'] as List? ?? [];
      allSessions.addAll(page);

      final hasNext = data['hasNext'] as bool? ?? false;
      if (!hasNext) break;
      nextCursor = data['nextCursor'] as String?;
      if (nextCursor == null) break;
    }

    return allSessions;
  }

  /// Fetch a single session by ID.
  /// Returns the raw session map (encrypted), or null if not found.
  Future<Map<String, dynamic>?> fetchSessionById(String sessionId) async {
    try {
      final response = await _client.get('/v1/sessions/$sessionId');

      if (!_isSuccess(response)) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      return data['session'] as Map<String, dynamic>?;
    } catch (e) {
      logger.warning('fetchSessionById failed for $sessionId: $e');
      return null;
    }
  }

  /// Delete a session by ID
  Future<void> deleteSession(String sessionId) async {
    final response = await _client.delete('/v1/sessions/$sessionId');

    if (!_isSuccess(response)) {
      throw SessionsApiException(
        'Failed to delete session: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Update session metadata (encrypted)
  Future<void> updateSessionMetadata(
    String sessionId, {
    required String encryptedMetadata,
    required int expectedVersion,
  }) async {
    final response = await _client.post(
      '/v1/sessions/$sessionId/metadata',
      data: {'metadata': encryptedMetadata, 'expectedVersion': expectedVersion},
    );

    if (!_isSuccess(response)) {
      throw SessionsApiException(
        'Failed to update session metadata: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Update session agent state (encrypted)
  Future<void> updateSessionAgentState(
    String sessionId, {
    required String encryptedState,
    required int expectedVersion,
  }) async {
    final response = await _client.post(
      '/v1/sessions/$sessionId/agent-state',
      data: {'agentState': encryptedState, 'expectedVersion': expectedVersion},
    );

    if (!_isSuccess(response)) {
      throw SessionsApiException(
        'Failed to update session agent state: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Rename a session
  Future<void> renameSession(String sessionId, String newName) async {
    final response = await _client.post(
      '/v1/sessions/$sessionId/rename',
      data: {'name': newName},
    );

    if (!_isSuccess(response)) {
      throw SessionsApiException(
        'Failed to rename session: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Set session archive status
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    final response = await _client.post(
      '/v1/sessions/$sessionId/archive',
      data: {'archived': archived},
    );

    if (!_isSuccess(response)) {
      throw SessionsApiException(
        'Failed to ${archived ? 'archive' : 'unarchive'} session: '
        '${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Exception thrown by Sessions API operations
class SessionsApiException extends BaseApiException {
  const SessionsApiException(super.message, {super.statusCode});

  @override
  String toString() => 'SessionsApiException: $message';
}
