import 'package:dio/dio.dart';
import '../api/api_client.dart';

/// Service for push notification token registration (/v1/push-tokens)
/// Based on React Native's apiPush.ts
class PushService {
  static final PushService _instance = PushService._();
  factory PushService() => _instance;
  PushService._();

  final _apiClient = ApiClient();

  /// Register a push notification token
  Future<void> registerToken(String token) async {
    try {
      final response = await _apiClient.post(
        '/v1/push-tokens',
        data: {'token': token},
      );

      if (!_apiClient.isSuccess(response)) {
        throw PushException(
            'Failed to register push token: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw PushException('Failed to register push token');
      }
    } on DioException catch (e) {
      throw PushException('Failed to register push token: ${e.message}');
    }
  }
}

/// Exception for push notification operations
class PushException implements Exception {
  final String message;
  PushException(this.message);

  @override
  String toString() => 'PushException: $message';
}
