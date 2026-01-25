import 'dart:async';
import 'api_client.dart';
import '../models/kv.dart';

/// KV Store API client
/// Provides key-value storage operations
/// Based on React Native's apiKv.ts
class KvApi {
  final ApiClient _client;

  KvApi({ApiClient? client})
      : _client = client ?? ApiClient();

  /// Get a single value by key
  /// Returns null if key doesn't exist (404)
  Future<KvItem?> get(String key) async {
    final encodedKey = Uri.encodeComponent(key);
    final response = await _client.get('/v1/kv/$encodedKey');

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw KvApiException(
        'Failed to get KV value: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return KvItem.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw KvApiException('Failed to parse KV item: $e');
    }
  }

  /// List key-value pairs with optional prefix filter
  Future<KvListResponse> list({
    String? prefix,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{};
    if (prefix != null) {
      queryParams['prefix'] = prefix;
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }

    final response = await _client.get(
      '/v1/kv',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode != 200) {
      throw KvApiException(
        'Failed to list KV items: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return KvListResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw KvApiException('Failed to parse KV list response: $e');
    }
  }

  /// Get multiple values by keys (up to 100)
  Future<KvBulkGetResponse> bulkGet(List<String> keys) async {
    if (keys.isEmpty) {
      return const KvBulkGetResponse(values: []);
    }

    if (keys.length > 100) {
      throw const KvApiException(
        'Cannot bulk get more than 100 keys at once',
      );
    }

    final response = await _client.post(
      '/v1/kv/bulk',
      data: {'keys': keys},
    );

    if (response.statusCode != 200) {
      throw KvApiException(
        'Failed to bulk get KV values: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return KvBulkGetResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw KvApiException('Failed to parse bulk get response: $e');
    }
  }

  /// Atomically mutate multiple key-value pairs
  /// Supports create, update, and delete operations
  /// Uses optimistic concurrency control with version numbers
  Future<KvMutateResponse> mutate(List<KvMutation> mutations) async {
    if (mutations.isEmpty) {
      return const KvMutateSuccessResponse([]);
    }

    if (mutations.length > 100) {
      throw const KvApiException(
        'Cannot mutate more than 100 keys at once',
      );
    }

    final request = KvMutateRequest(mutations: mutations);
    final response = await _client.post(
      '/v1/kv',
      data: request.toJson(),
    );

    // Handle version mismatch (409 Conflict)
    if (response.statusCode == 409) {
      try {
        return KvMutateErrorResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } catch (e) {
        throw KvApiException('Failed to parse mutate error response: $e');
      }
    }

    if (response.statusCode != 200) {
      throw KvApiException(
        'Failed to mutate KV values: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return KvMutateSuccessResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw KvApiException('Failed to parse mutate response: $e');
    }
  }

  /// Set a single key-value pair
  /// Creates new key if version is -1, updates existing if version matches
  /// Returns the new version of the key
  Future<int> set(
    String key,
    String value, {
    int version = -1,
  }) async {
    final result = await mutate([
      KvMutation(key: key, value: value, version: version),
    ]);

    if (result.isError) {
      final error = result.errors.first;
      throw KvApiException(
        'Failed to set key "$key": ${error.error} '
        '(current version: ${error.version})',
        statusCode: 409,
      );
    }

    return result.results.first.version;
  }

  /// Delete a single key
  Future<void> delete(String key, int version) async {
    final result = await mutate([
      KvMutation(key: key, value: null, version: version),
    ]);

    if (result.isError) {
      final error = result.errors.first;
      throw KvApiException(
        'Failed to delete key "$key": ${error.error} '
        '(current version: ${error.version})',
        statusCode: 409,
      );
    }
  }

  /// Get keys with a specific prefix
  Future<List<KvItem>> getByPrefix(String prefix, {int limit = 100}) async {
    final response = await list(prefix: prefix, limit: limit);
    return response.items;
  }
}

/// Exception thrown by KV API operations
class KvApiException implements Exception {
  final String message;
  final int? statusCode;

  const KvApiException(this.message, {this.statusCode});

  @override
  String toString() => 'KvApiException: $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KvApiException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => Object.hash(message, statusCode);
}
