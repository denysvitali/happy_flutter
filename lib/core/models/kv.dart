/// Key-Value store models for /v1/kv endpoints
/// Based on React Native's apiKv.ts

/// A single key-value item
class KvItem {
  final String key;
  final String value;
  final int version;

  KvItem({
    required this.key,
    required this.value,
    required this.version,
  });

  factory KvItem.fromJson(Map<String, dynamic> json) {
    return KvItem(
      key: json['key'] as String,
      value: json['value'] as String,
      version: json['version'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'version': version,
    };
  }
}

/// Response for listing KV items
class KvListResponse {
  final List<KvItem> items;

  KvListResponse({required this.items});

  factory KvListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((e) => KvItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvListResponse(items: items);
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

/// Request for bulk getting KV items
class KvBulkGetRequest {
  final List<String> keys;

  KvBulkGetRequest({required this.keys});

  Map<String, dynamic> toJson() {
    return {'keys': keys};
  }
}

/// Response for bulk getting KV items
class KvBulkGetResponse {
  final List<KvItem> values;

  const KvBulkGetResponse({required this.values});

  factory KvBulkGetResponse.fromJson(Map<String, dynamic> json) {
    final values = (json['values'] as List<dynamic>)
        .map((e) => KvItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvBulkGetResponse(values: values);
  }

  Map<String, dynamic> toJson() {
    return {
      'values': values.map((e) => e.toJson()).toList(),
    };
  }
}

/// A single mutation operation
class KvMutation {
  final String key;
  final String? value; // null to delete
  final int version; // -1 for new keys

  KvMutation({
    required this.key,
    required this.value,
    required this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'version': version,
    };
  }
}

/// Request for mutating KV items
class KvMutateRequest {
  final List<KvMutation> mutations;

  KvMutateRequest({required this.mutations});

  Map<String, dynamic> toJson() {
    return {
      'mutations': mutations.map((e) => e.toJson()).toList(),
    };
  }
}

/// Result of a single mutation
class KvMutateResult {
  final String key;
  final int version;

  KvMutateResult({required this.key, required this.version});

  factory KvMutateResult.fromJson(Map<String, dynamic> json) {
    return KvMutateResult(
      key: json['key'] as String,
      version: json['version'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'version': version,
    };
  }
}

/// Error details for a failed mutation
class KvMutateError {
  final String key;
  final String error; // 'version-mismatch'
  final int version;
  final String? value;

  KvMutateError({
    required this.key,
    required this.error,
    required this.version,
    this.value,
  });

  factory KvMutateError.fromJson(Map<String, dynamic> json) {
    return KvMutateError(
      key: json['key'] as String,
      error: json['error'] as String,
      version: json['version'] as int,
      value: json['value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'error': error,
      'version': version,
      'value': value,
    };
  }
}

/// Success response from mutate operation
class KvMutateSuccessResponse extends KvMutateResponse {
  final List<KvMutateResult> results;

  const KvMutateSuccessResponse(this.results);

  factory KvMutateSuccessResponse.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>)
        .map((e) => KvMutateResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvMutateSuccessResponse(results);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': true,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

/// Error response from mutate operation
class KvMutateErrorResponse extends KvMutateResponse {
  final List<KvMutateError> errors;

  const KvMutateErrorResponse(this.errors);

  factory KvMutateErrorResponse.fromJson(Map<String, dynamic> json) {
    final errors = (json['errors'] as List<dynamic>)
        .map((e) => KvMutateError.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvMutateErrorResponse(errors);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': false,
      'errors': errors.map((e) => e.toJson()).toList(),
    };
  }
}

/// Union type for mutate response
sealed class KvMutateResponse {
  const KvMutateResponse();

  bool get isSuccess => this is KvMutateSuccessResponse;
  bool get isError => this is KvMutateErrorResponse;

  List<KvMutateResult> get results =>
      (this as KvMutateSuccessResponse).results;

  List<KvMutateError> get errors =>
      (this as KvMutateErrorResponse).errors;

  factory KvMutateResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == true) {
      final results = (json['results'] as List<dynamic>)
          .map((e) => KvMutateResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return KvMutateSuccessResponse(results);
    } else {
      final errors = (json['errors'] as List<dynamic>)
          .map((e) => KvMutateError.fromJson(e as Map<String, dynamic>))
          .toList();
      return KvMutateErrorResponse(errors);
    }
  }
}
