import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/kv.dart';

/// Service for key-value store operations (/v1/kv/*)
/// Based on React Native's apiKv.ts
class KvService {
  static final KvService _instance = KvService._();
  factory KvService() => _instance;
  KvService._();

  final _apiClient = ApiClient();

  /// Get a single value by key
  /// Returns null if key is not found (404)
  Future<KvItem?> get(String key) async {
    try {
      final response = await _apiClient.get('/v1/kv/${Uri.encodeComponent(key)}');

      if (response.statusCode == 404) {
        return null;
      }

      if (!_apiClient.isSuccess(response)) {
        throw KvException('Failed to get KV value: ${response.statusCode}');
      }

      return KvItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw KvException('Failed to get KV value: ${e.message}');
    }
  }

  /// List key-value pairs with optional prefix filter
  Future<KvListResponse> list({String? prefix, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (prefix != null) queryParams['prefix'] = prefix;
    if (limit != null) queryParams['limit'] = limit;

    try {
      final response = await _apiClient.get(
        '/v1/kv',
        queryParameters: queryParams,
      );

      if (!_apiClient.isSuccess(response)) {
        throw KvException('Failed to list KV items: ${response.statusCode}');
      }

      return KvListResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw KvException('Failed to list KV items: ${e.message}');
    }
  }

  /// Get multiple values by keys (up to 100)
  Future<KvBulkGetResponse> bulkGet(List<String> keys) async {
    if (keys.isEmpty) {
      return KvBulkGetResponse(values: []);
    }

    if (keys.length > 100) {
      throw ArgumentError('Cannot bulk get more than 100 keys at once');
    }

    try {
      final response = await _apiClient.post(
        '/v1/kv/bulk',
        data: {'keys': keys},
      );

      if (!_apiClient.isSuccess(response)) {
        throw KvException('Failed to bulk get KV values: ${response.statusCode}');
      }

      return KvBulkGetResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw KvException('Failed to bulk get KV values: ${e.message}');
    }
  }

  /// Atomically mutate multiple key-value pairs
  /// Supports create, update, and delete operations
  /// Uses optimistic concurrency control with version numbers
  Future<KvMutateResponse> mutate(List<KvMutation> mutations) async {
    if (mutations.isEmpty) {
      return KvMutateResponse.success([]);
    }

    if (mutations.length > 100) {
      throw ArgumentError('Cannot mutate more than 100 keys at once');
    }

    final request = {
      'mutations': mutations.map((m) => m.toJson()).toList(),
    };

    try {
      final response = await _apiClient.post(
        '/v1/kv',
        data: request,
      );

      if (response.statusCode == 409) {
        return KvMutateResponse.fromJson(response.data as Map<String, dynamic>);
      }

      if (!_apiClient.isSuccess(response)) {
        throw KvException('Failed to mutate KV values: ${response.statusCode}');
      }

      return KvMutateResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw KvException('Failed to mutate KV values: ${e.message}');
    }
  }

  /// Set a single key-value pair
  /// Creates new key if version is -1, updates existing if version matches
  /// Returns the new version number
  Future<int> set(String key, String value, {int version = -1}) async {
    final result = await mutate([
      KvMutation(key: key, value: value, version: version),
    ]);

    if (result is KvMutateSuccessResponse) {
      final results = result.results;
      if (results.isEmpty) {
        throw KvException('Empty mutation result');
      }
      return results.first.version;
    } else if (result is KvMutateErrorResponse) {
      final error = result.errors.first;
      throw VersionMismatchException(
        key: error.key,
        currentVersion: error.version,
        reason: error.error,
      );
    }
    throw KvException('Unknown mutation response type');
  }

  /// Delete a single key
  /// Requires the current version number for optimistic locking
  Future<void> delete(String key, int version) async {
    final result = await mutate([
      KvMutation(key: key, value: null, version: version),
    ]);

    if (result is KvMutateSuccessResponse) {
      return;
    } else if (result is KvMutateErrorResponse) {
      final error = result.errors.first;
      throw VersionMismatchException(
        key: error.key,
        currentVersion: error.version,
        reason: error.error,
      );
    }
  }

  /// Get keys with a specific prefix
  Future<List<KvItem>> getByPrefix(String prefix, {int limit = 100}) async {
    final response = await list(prefix: prefix, limit: limit);
    return response.items;
  }
}

/// Exception for KV operations
class KvException implements Exception {
  final String message;
  KvException(this.message);

  @override
  String toString() => 'KvException: $message';
}

/// Exception for version mismatch errors
class VersionMismatchException extends KvException {
  final String key;
  final int currentVersion;
  final String reason;

  VersionMismatchException({
    required this.key,
    required this.currentVersion,
    required this.reason,
  }) : super('Version mismatch for key "$key": $reason (current version: $currentVersion)');
}
