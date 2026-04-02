/// Key-Value store models for /v1/kv endpoints
/// Based on React Native's apiKv.ts
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'kv.freezed.dart';
part 'kv.g.dart';

/// A single key-value item
@freezed
abstract class KvItem with _$KvItem {
  const factory KvItem({
    required String key,
    required String value,
    required int version,
  }) = _KvItem;

  factory KvItem.fromJson(Map<String, dynamic> json) =>
      _$KvItemFromJson(json);
}

/// Response for listing KV items
@freezed
abstract class KvListResponse with _$KvListResponse {
  const factory KvListResponse({
    required List<KvItem> items,
  }) = _KvListResponse;

  factory KvListResponse.fromJson(Map<String, dynamic> json) =>
      _$KvListResponseFromJson(json);
}

/// Request for bulk getting KV items
@freezed
abstract class KvBulkGetRequest with _$KvBulkGetRequest {
  const factory KvBulkGetRequest({
    required List<String> keys,
  }) = _KvBulkGetRequest;

  factory KvBulkGetRequest.fromJson(Map<String, dynamic> json) =>
      _$KvBulkGetRequestFromJson(json);
}

/// Response for bulk getting KV items
@freezed
abstract class KvBulkGetResponse with _$KvBulkGetResponse {
  const factory KvBulkGetResponse({
    required List<KvItem> values,
  }) = _KvBulkGetResponse;

  factory KvBulkGetResponse.fromJson(Map<String, dynamic> json) =>
      _$KvBulkGetResponseFromJson(json);
}

/// A single mutation operation
@freezed
abstract class KvMutation with _$KvMutation {
  const factory KvMutation({
    required String key,
    required int version, // -1 for new keys
    String? value, // null to delete
  }) = _KvMutation;

  factory KvMutation.fromJson(Map<String, dynamic> json) =>
      _$KvMutationFromJson(json);
}

/// Request for mutating KV items
@freezed
abstract class KvMutateRequest with _$KvMutateRequest {
  const factory KvMutateRequest({
    required List<KvMutation> mutations,
  }) = _KvMutateRequest;

  factory KvMutateRequest.fromJson(Map<String, dynamic> json) =>
      _$KvMutateRequestFromJson(json);
}

/// Result of a single mutation
@freezed
abstract class KvMutateResult with _$KvMutateResult {
  const factory KvMutateResult({
    required String key,
    required int version,
  }) = _KvMutateResult;

  factory KvMutateResult.fromJson(Map<String, dynamic> json) =>
      _$KvMutateResultFromJson(json);
}

/// Error details for a failed mutation
@freezed
abstract class KvMutateError with _$KvMutateError {
  const factory KvMutateError({
    required String key,
    required String error, // 'version-mismatch'
    required int version,
    String? value,
  }) = _KvMutateError;

  factory KvMutateError.fromJson(Map<String, dynamic> json) =>
      _$KvMutateErrorFromJson(json);
}

/// Success response from mutate operation
class KvMutateSuccessResponse extends KvMutateResponse {
  const KvMutateSuccessResponse(this.results);

  factory KvMutateSuccessResponse.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>)
        .map((e) => KvMutateResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvMutateSuccessResponse(results);
  }
  @override
  final List<KvMutateResult> results;

  Map<String, dynamic> toJson() {
    return {
      'success': true,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

/// Error response from mutate operation
class KvMutateErrorResponse extends KvMutateResponse {
  const KvMutateErrorResponse(this.errors);

  factory KvMutateErrorResponse.fromJson(Map<String, dynamic> json) {
    final errors = (json['errors'] as List<dynamic>)
        .map((e) => KvMutateError.fromJson(e as Map<String, dynamic>))
        .toList();
    return KvMutateErrorResponse(errors);
  }
  @override
  final List<KvMutateError> errors;

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

  bool get isSuccess => this is KvMutateSuccessResponse;
  bool get isError => this is KvMutateErrorResponse;

  List<KvMutateResult> get results =>
      (this as KvMutateSuccessResponse).results;

  List<KvMutateError> get errors =>
      (this as KvMutateErrorResponse).errors;
}
