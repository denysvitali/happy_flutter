import 'dart:async';

import '../services/logger_service.dart' show logger;
import 'api_client.dart';
import 'base_api_exception.dart';

/// Connected Services API client
/// Handles connecting/disconnecting third-party services (Claude, GitHub, OpenAI)
/// Based on React Native's apiServices.ts
class ServicesApi {
  ServicesApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Connect a service to the user's account
  /// Used after OAuth flow completion or direct token registration
  Future<void> connectService(String service, String token) async {
    if (service.isEmpty) {
      throw const ServicesApiException('Service name cannot be empty');
    }
    if (token.isEmpty) {
      throw const ServicesApiException('Service token cannot be empty');
    }

    final response = await _client.post(
      '/v1/connect/$service/register',
      data: {'token': token},
    );

    if (response.statusCode != 200) {
      throw ServicesApiException(
        'Failed to connect $service: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw ServicesApiException('Failed to connect $service account');
    }

    logger.info('$service connected successfully');
  }

  /// Disconnect a connected service from the user's account
  Future<void> disconnectService(String service) async {
    if (service.isEmpty) {
      throw const ServicesApiException('Service name cannot be empty');
    }

    final response = await _client.delete('/v1/connect/$service');

    if (response.statusCode == 404) {
      final error = response.data as Map<String, dynamic>?;
      throw ServicesApiException(
        error?['error'] ?? '$service account not connected',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw ServicesApiException(
        'Failed to disconnect $service: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw ServicesApiException('Failed to disconnect $service account');
    }

    logger.info('$service disconnected successfully');
  }

  /// Check if a service is currently connected
  /// Returns true if connected, false otherwise
  Future<bool> isServiceConnected(String service) async {
    if (service.isEmpty) {
      throw const ServicesApiException('Service name cannot be empty');
    }

    try {
      final response = await _client.get('/v1/connect/$service');

      // 200 means connected, 404 means not connected
      return response.statusCode == 200;
    } catch (e, s) {
      logger.warning('Error checking $service connection: $e', e, s);
      return false;
    }
  }

  /// Get connection status for all supported services
  Future<Map<String, bool>> getAllConnectionStatus() async {
    const services = ['github', 'claude', 'openai'];
    final results = await Future.wait(
      services.map((service) async {
        try {
          return await isServiceConnected(service);
        } catch (e, s) {
          logger.warning('Error checking $service status: $e', e, s);
          return false;
        }
      }),
    );
    return Map.fromIterables(services, results);
  }

  /// Connect GitHub service (convenience method)
  Future<void> connectGitHub(String token) async {
    await connectService('github', token);
  }

  /// Disconnect GitHub service (convenience method)
  Future<void> disconnectGitHub() async {
    await disconnectService('github');
  }

  /// Connect Claude service (convenience method)
  Future<void> connectClaude(String token) async {
    await connectService('claude', token);
  }

  /// Disconnect Claude service (convenience method)
  Future<void> disconnectClaude() async {
    await disconnectService('claude');
  }

  /// Connect OpenAI service (convenience method)
  Future<void> connectOpenAI(String token) async {
    await connectService('openai', token);
  }

  /// Disconnect OpenAI service (convenience method)
  Future<void> disconnectOpenAI() async {
    await disconnectService('openai');
  }
}

/// Exception thrown by Services API operations
class ServicesApiException extends BaseApiException {
  const ServicesApiException(super.message, {super.statusCode});

  @override
  String toString() => 'ServicesApiException: $message';
}
