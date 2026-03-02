import 'dart:async';

import '../services/logger_service.dart' show logger;
import 'api_client.dart';
import 'base_api_exception.dart';

/// Push Notifications API client
/// Handles push notification token registration
/// Based on React Native's apiPush.ts
class PushApi {
  PushApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Register a push notification token with the server
  /// Used for receiving push notifications on the device
  Future<void> registerToken(String token) async {
    if (token.isEmpty) {
      throw const PushApiException('Push token cannot be empty');
    }

    final response = await _client.post(
      '/v1/push-tokens',
      data: {'token': token},
    );

    if (response.statusCode != 200) {
      throw PushApiException(
        'Failed to register push token: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw const PushApiException('Failed to register push token');
    }

    logger.info('Push token registered successfully');
  }

  /// Unregister a push notification token
  Future<void> unregisterToken(String token) async {
    if (token.isEmpty) {
      throw const PushApiException('Push token cannot be empty');
    }

    final response = await _client.delete('/v1/push-tokens/$token');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw PushApiException(
        'Failed to unregister push token: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    logger.info('Push token unregistered successfully');
  }

  /// Update an existing push notification token
  Future<void> updateToken(String oldToken, String newToken) async {
    if (oldToken.isEmpty || newToken.isEmpty) {
      throw const PushApiException('Push tokens cannot be empty');
    }

    final response = await _client.put(
      '/v1/push-tokens/$oldToken',
      data: {'token': newToken},
    );

    if (response.statusCode != 200) {
      throw PushApiException(
        'Failed to update push token: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw const PushApiException('Failed to update push token');
    }

    logger.info('Push token updated successfully');
  }
}

/// Exception thrown by Push API operations
class PushApiException extends BaseApiException {
  const PushApiException(super.message, {super.statusCode});

  @override
  String toString() => 'PushApiException: $message';
}
