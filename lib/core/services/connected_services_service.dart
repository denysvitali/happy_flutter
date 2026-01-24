import 'package:dio/dio.dart';
import '../api/api_client.dart';

/// Service for connecting/disconnecting third-party services (/v1/connect/*)
/// Based on React Native's apiServices.ts
class ConnectedServicesService {
  static final ConnectedServicesService _instance =
      ConnectedServicesService._();
  factory ConnectedServicesService() => _instance;
  ConnectedServicesService._();

  final _apiClient = ApiClient();

  /// Connect a service to the user's account
  /// service: The service identifier (e.g., 'github', 'slack')
  /// token: The OAuth token or credentials for the service
  Future<void> connect(String service, dynamic token) async {
    try {
      final response = await _apiClient.post(
        '/v1/connect/$service/register',
        data: {'token': token.toString()},
      );

      if (!_apiClient.isSuccess(response)) {
        throw ConnectedServicesException(
            'Failed to connect $service: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ConnectedServicesException('Failed to connect $service account');
      }
    } on DioException catch (e) {
      throw ConnectedServicesException(
          'Failed to connect $service: ${e.message}');
    }
  }

  /// Disconnect a connected service from the user's account
  Future<void> disconnect(String service) async {
    try {
      final response = await _apiClient.delete('/v1/connect/$service');

      if (response.statusCode == 404) {
        final data = response.data as Map<String, dynamic>;
        throw ConnectedServicesException(
            data['error'] as String? ?? '$service account not connected');
      }

      if (!_apiClient.isSuccess(response)) {
        throw ConnectedServicesException(
            'Failed to disconnect $service: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ConnectedServicesException('Failed to disconnect $service account');
      }
    } on DioException catch (e) {
      throw ConnectedServicesException(
          'Failed to disconnect $service: ${e.message}');
    }
  }
}

/// Exception for connected services operations
class ConnectedServicesException implements Exception {
  final String message;
  ConnectedServicesException(this.message);

  @override
  String toString() => 'ConnectedServicesException: $message';
}
