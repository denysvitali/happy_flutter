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
    final sessionIds = <String>{};
    final seenCursors = <String>{?cursor};
    var nextCursor = cursor;

    // Bound even a broken server that keeps inventing fresh cursors and IDs.
    const maxPages = 1000;
    for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
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

      // A full fetch replaces the local catalog. Never turn an incomplete
      // response into an authoritative empty or partial snapshot.
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['sessions'] is! List ||
          data['hasNext'] is! bool ||
          (data['nextCursor'] != null && data['nextCursor'] is! String)) {
        throw const SessionsApiException('Invalid sessions page envelope');
      }
      final page = data['sessions'] as List;
      for (final session in page) {
        if (session is! Map<String, dynamic>) {
          throw const SessionsApiException('Invalid session in sessions page');
        }
        final id = session['id'];
        if (id is! String || id.trim().isEmpty || !sessionIds.add(id)) {
          throw const SessionsApiException(
            'Invalid or duplicate session ID in sessions page',
          );
        }
      }

      final hasNext = data['hasNext'] as bool;
      allSessions.addAll(page);
      if (!hasNext) return allSessions;
      nextCursor = data['nextCursor'] as String?;
      if (page.isEmpty ||
          nextCursor == null ||
          nextCursor.trim().isEmpty ||
          !seenCursors.add(nextCursor)) {
        throw const SessionsApiException('Sessions pagination did not advance');
      }
    }

    throw const SessionsApiException('Sessions pagination exceeded page limit');
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
    } catch (e, s) {
      logger.warning('fetchSessionById failed for $sessionId: $e', e, s);
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

  /// Set session archive status. Archiving a deleted session is idempotent.
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    final response = await _client.post(
      '/v1/sessions/$sessionId/archive',
      data: {'archived': archived},
    );

    // A deleted session already satisfies archive intent. Unarchive still
    // requires an existing session, so its 404 remains an error.
    if (archived && response.statusCode == 404) return;

    if (!_isSuccess(response)) {
      logger.warning(
        'setSessionArchived failed: '
        'sessionId=$sessionId archived=$archived '
        'status=${response.statusCode} '
        'body=${response.data}',
      );
      throw SessionsApiException(
        'Failed to ${archived ? 'archive' : 'unarchive'} session: '
        '${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    logger.debug(
      'setSessionArchived success: '
      'sessionId=$sessionId archived=$archived',
    );
  }
}

/// Exception thrown by Sessions API operations
class SessionsApiException extends BaseApiException {
  const SessionsApiException(super.message, {super.statusCode});

  @override
  String toString() => 'SessionsApiException: $message';
}
