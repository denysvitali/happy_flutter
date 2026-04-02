/// Artifact models for encrypted content storage
/// Matches React Native implementation in
/// ../happy/sources/sync/artifactTypes.ts
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'artifact.freezed.dart';
part 'artifact.g.dart';

int _asApiInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  throw FormatException(
    'Expected int, got ${value.runtimeType}',
  );
}

String _asRequiredString(dynamic value) {
  if (value is String) return value;
  throw FormatException('Expected String, got ${value.runtimeType}');
}

int? _asApiIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

List<String>? _stringListOrNull(dynamic value) {
  if (value is List) {
    final list = value.whereType<String>().toList();
    return list.isEmpty ? null : list;
  }
  return null;
}

/// Encrypted artifact from API (matches React Native Artifact interface)
@freezed
abstract class Artifact with _$Artifact {
  const factory Artifact({
    @JsonKey(fromJson: _asRequiredString) required String id,
    // Base64 encoded encrypted JSON
    @JsonKey(fromJson: _asRequiredString) required String header,
    @JsonKey(fromJson: _asApiInt) required int headerVersion,
    // Base64 encoded encryption key
    @JsonKey(fromJson: _asRequiredString) required String dataEncryptionKey,
    @JsonKey(fromJson: _asApiInt) required int seq,
    @JsonKey(fromJson: _asApiInt) required int createdAt,
    @JsonKey(fromJson: _asApiInt) required int updatedAt,
    String? body, // Base64 encoded encrypted JSON
    @JsonKey(fromJson: _asApiIntNullable) int? bodyVersion,
  }) = _Artifact;

  factory Artifact.fromJson(Map<String, dynamic> json) =>
      _$ArtifactFromJson(json);
}

/// Decrypted artifact header (matches React Native ArtifactHeader interface)
@freezed
abstract class ArtifactHeader with _$ArtifactHeader {
  const factory ArtifactHeader({
    String? title,
    @JsonKey(fromJson: _stringListOrNull) List<String>? sessions,
    bool? draft,
  }) = _ArtifactHeader;

  factory ArtifactHeader.fromJson(Map<String, dynamic> json) =>
      _$ArtifactHeaderFromJson(json);
}

/// Decrypted artifact body (matches React Native ArtifactBody interface)
@freezed
abstract class ArtifactBody with _$ArtifactBody {
  const factory ArtifactBody({
    String? body,
  }) = _ArtifactBody;

  factory ArtifactBody.fromJson(Map<String, dynamic> json) =>
      _$ArtifactBodyFromJson(json);
}

/// Decrypted artifact for UI (matches React Native DecryptedArtifact interface)
@freezed
abstract class DecryptedArtifact with _$DecryptedArtifact {
  const factory DecryptedArtifact({
    required String id,
    @JsonKey(fromJson: _asApiInt) required int headerVersion,
    @JsonKey(fromJson: _asApiInt) required int seq,
    @JsonKey(fromJson: _asApiInt) required int createdAt,
    @JsonKey(fromJson: _asApiInt) required int updatedAt,
    String? title,
    @JsonKey(fromJson: _stringListOrNull)
    List<String>? sessions, // Optional array of session IDs
    bool? draft, // Optional draft flag - hides artifact from list
    String? body, // Only loaded when viewing full artifact
    @JsonKey(fromJson: _asApiIntNullable) int? bodyVersion,
    @Default(true) bool isDecrypted,
  }) = _DecryptedArtifact;

  factory DecryptedArtifact.fromJson(Map<String, dynamic> json) =>
      _$DecryptedArtifactFromJson(json);

  /// Create a decrypted artifact from encrypted artifact
  factory DecryptedArtifact.fromArtifact(
    Artifact artifact,
    ArtifactHeader header, [
    ArtifactBody? body,
  ]) {
    return DecryptedArtifact(
      id: artifact.id,
      title: header.title,
      sessions: header.sessions,
      draft: header.draft,
      body: body?.body,
      headerVersion: artifact.headerVersion,
      bodyVersion: artifact.bodyVersion,
      seq: artifact.seq,
      createdAt: artifact.createdAt,
      updatedAt: artifact.updatedAt,
      isDecrypted: true,
    );
  }
}

/// Request to create a new artifact
/// (matches React Native ArtifactCreateRequest)
@freezed
abstract class ArtifactCreateRequest with _$ArtifactCreateRequest {
  const factory ArtifactCreateRequest({
    required String id, // UUID generated client-side
    required String header, // Base64 encoded encrypted header
    required String body, // Base64 encoded encrypted body
    required String dataEncryptionKey,
  }) = _ArtifactCreateRequest;

  factory ArtifactCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$ArtifactCreateRequestFromJson(json);
}

/// Request to update an existing artifact
@freezed
abstract class ArtifactUpdateRequest with _$ArtifactUpdateRequest {
  const factory ArtifactUpdateRequest({
    String? header, // Base64 encoded encrypted header
    int? expectedHeaderVersion,
    String? body, // Base64 encoded encrypted body
    int? expectedBodyVersion,
  }) = _ArtifactUpdateRequest;

  const ArtifactUpdateRequest._();

  factory ArtifactUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ArtifactUpdateRequestFromJson(json);

  /// Conditional serialization: only include keys when values are present
  Map<String, dynamic> toConditionalJson() {
    final json = <String, dynamic>{};
    if (header != null) {
      json['header'] = header;
      json['expectedHeaderVersion'] = expectedHeaderVersion;
    }
    if (body != null) {
      json['body'] = body;
      json['expectedBodyVersion'] = expectedBodyVersion;
    }
    return json;
  }
}

/// Response from update operation (matches React Native ArtifactUpdateResponse)
@freezed
abstract class ArtifactUpdateResponse with _$ArtifactUpdateResponse {
  const factory ArtifactUpdateResponse({
    @Default(false) bool success,
    int? headerVersion,
    int? bodyVersion,
    String? error,
    int? currentHeaderVersion,
    int? currentBodyVersion,
    String? currentHeader,
    String? currentBody,
  }) = _ArtifactUpdateResponse;

  factory ArtifactUpdateResponse.fromJson(Map<String, dynamic> json) =>
      _$ArtifactUpdateResponseFromJson(json);
}

/// Artifact folder for organization
@freezed
abstract class ArtifactFolder with _$ArtifactFolder {
  const factory ArtifactFolder({
    @JsonKey(fromJson: _asRequiredString) required String id,
    @JsonKey(fromJson: _asRequiredString) required String sessionId,
    @JsonKey(fromJson: _asRequiredString) required String name,
    required int createdAt,
    required int updatedAt,
    String? parentId,
  }) = _ArtifactFolder;

  factory ArtifactFolder.fromJson(Map<String, dynamic> json) =>
      _$ArtifactFolderFromJson(json);
}
