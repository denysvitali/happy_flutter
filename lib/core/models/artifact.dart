/// Artifact models for encrypted content storage
/// Matches React Native implementation in ../happy/sources/sync/artifactTypes.ts
library;

String _asApiString(dynamic value, String fieldName) {
  if (value is String) return value;
  throw FormatException(
    'Expected String for $fieldName, got ${value.runtimeType}',
  );
}

int _asApiInt(dynamic value, String fieldName) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  throw FormatException(
    'Expected int for $fieldName, got ${value.runtimeType}',
  );
}

String? _asApiStringOptional(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return null;
}

int? _asApiIntOptional(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

/// Encrypted artifact from API (matches React Native Artifact interface)
class Artifact {

  Artifact({
    required this.id,
    required this.header,
    required this.headerVersion,
    required this.dataEncryptionKey,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    this.body,
    this.bodyVersion,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: _asApiString(json['id'], 'id'),
      header: _asApiString(json['header'], 'header'),
      headerVersion: _asApiInt(json['headerVersion'], 'headerVersion'),
      body: _asApiStringOptional(json['body']),
      bodyVersion: _asApiIntOptional(json['bodyVersion']),
      dataEncryptionKey: _asApiString(
        json['dataEncryptionKey'],
        'dataEncryptionKey',
      ),
      seq: _asApiInt(json['seq'], 'seq'),
      createdAt: _asApiInt(json['createdAt'], 'createdAt'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
    );
  }
  final String id;
  final String header; // Base64 encoded encrypted JSON
  final int headerVersion;
  final String? body; // Base64 encoded encrypted JSON
  final int? bodyVersion; // Only in full fetch
  final String dataEncryptionKey; // Base64 encoded encryption key
  final int seq;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'headerVersion': headerVersion,
      'body': body,
      'bodyVersion': bodyVersion,
      'dataEncryptionKey': dataEncryptionKey,
      'seq': seq,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Artifact copyWith({
    String? id,
    String? header,
    int? headerVersion,
    String? body,
    int? bodyVersion,
    String? dataEncryptionKey,
    int? seq,
    int? createdAt,
    int? updatedAt,
  }) {
    return Artifact(
      id: id ?? this.id,
      header: header ?? this.header,
      headerVersion: headerVersion ?? this.headerVersion,
      body: body ?? this.body,
      bodyVersion: bodyVersion ?? this.bodyVersion,
      dataEncryptionKey: dataEncryptionKey ?? this.dataEncryptionKey,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artifact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          header == other.header &&
          headerVersion == other.headerVersion &&
          body == other.body &&
          bodyVersion == other.bodyVersion &&
          dataEncryptionKey == other.dataEncryptionKey &&
          seq == other.seq &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        header,
        headerVersion,
        body,
        bodyVersion,
        dataEncryptionKey,
        seq,
        createdAt,
        updatedAt,
      );
}

/// Decrypted artifact header (matches React Native ArtifactHeader interface)
class ArtifactHeader {

  ArtifactHeader({
    this.title,
    this.sessions,
    this.draft,
  });

  factory ArtifactHeader.fromJson(Map<String, dynamic> json) {
    return ArtifactHeader(
      title: json['title'] as String?,
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      draft: json['draft'] as bool?,
    );
  }
  final String? title;
  final List<String>? sessions; // Optional array of session IDs
  final bool? draft;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sessions': sessions,
      'draft': draft,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtifactHeader &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          sessions == other.sessions &&
          draft == other.draft;

  @override
  int get hashCode => Object.hash(title, sessions, draft);
}

/// Decrypted artifact body (matches React Native ArtifactBody interface)
class ArtifactBody {

  ArtifactBody({this.body});

  factory ArtifactBody.fromJson(Map<String, dynamic> json) {
    return ArtifactBody(
      body: json['body'] as String?,
    );
  }
  final String? body;

  Map<String, dynamic> toJson() {
    return {
      'body': body,
    };
  }
}

/// Decrypted artifact for UI (matches React Native DecryptedArtifact interface)
class DecryptedArtifact { // Whether decryption was successful

  DecryptedArtifact({
    required this.id,
    required this.headerVersion,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.sessions,
    this.draft,
    this.body,
    this.bodyVersion,
    this.isDecrypted = true,
  });

  factory DecryptedArtifact.fromJson(Map<String, dynamic> json) {
    return DecryptedArtifact(
      id: _asApiString(json['id'], 'id'),
      title: _asApiStringOptional(json['title']),
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      draft: json['draft'] as bool?,
      body: _asApiStringOptional(json['body']),
      headerVersion: _asApiInt(json['headerVersion'], 'headerVersion'),
      bodyVersion: _asApiIntOptional(json['bodyVersion']),
      seq: _asApiInt(json['seq'], 'seq'),
      createdAt: _asApiInt(json['createdAt'], 'createdAt'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
      isDecrypted: json['isDecrypted'] as bool? ?? true,
    );
  }

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
  final String id;
  final String? title;
  final List<String>? sessions; // Optional array of session IDs
  final bool? draft; // Optional draft flag - hides artifact from list
  final String? body; // Only loaded when viewing full artifact
  final int headerVersion;
  final int? bodyVersion;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final bool isDecrypted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sessions': sessions,
      'draft': draft,
      'body': body,
      'headerVersion': headerVersion,
      'bodyVersion': bodyVersion,
      'seq': seq,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDecrypted': isDecrypted,
    };
  }

  DecryptedArtifact copyWith({
    String? id,
    String? title,
    List<String>? sessions,
    bool? draft,
    String? body,
    int? headerVersion,
    int? bodyVersion,
    int? seq,
    int? createdAt,
    int? updatedAt,
    bool? isDecrypted,
  }) {
    return DecryptedArtifact(
      id: id ?? this.id,
      title: title ?? this.title,
      sessions: sessions != null
          ? List<String>.from(sessions)
          : (this.sessions != null
              ? List<String>.from(this.sessions!)
              : null),
      draft: draft ?? this.draft,
      body: body ?? this.body,
      headerVersion: headerVersion ?? this.headerVersion,
      bodyVersion: bodyVersion ?? this.bodyVersion,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDecrypted: isDecrypted ?? this.isDecrypted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecryptedArtifact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          sessions == other.sessions &&
          draft == other.draft &&
          body == other.body &&
          headerVersion == other.headerVersion &&
          bodyVersion == other.bodyVersion &&
          seq == other.seq &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isDecrypted == other.isDecrypted;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        sessions,
        draft,
        body,
        headerVersion,
        bodyVersion,
        seq,
        createdAt,
        updatedAt,
        isDecrypted,
      );
}

/// Request to create a new artifact
/// (matches React Native ArtifactCreateRequest)
class ArtifactCreateRequest {

  ArtifactCreateRequest({
    required this.id,
    required this.header,
    required this.body,
    required this.dataEncryptionKey,
  });
  final String id; // UUID generated client-side
  final String header; // Base64 encoded encrypted header
  final String body; // Base64 encoded encrypted body
  final String dataEncryptionKey;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'body': body,
      'dataEncryptionKey': dataEncryptionKey,
    };
  }
}

/// Request to update an existing artifact
class ArtifactUpdateRequest {

  ArtifactUpdateRequest({
    this.header,
    this.expectedHeaderVersion,
    this.body,
    this.expectedBodyVersion,
  });
  final String? header; // Base64 encoded encrypted header
  final int? expectedHeaderVersion;
  final String? body; // Base64 encoded encrypted body
  final int? expectedBodyVersion;

  Map<String, dynamic> toJson() {
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
class ArtifactUpdateResponse {

  ArtifactUpdateResponse({
    required this.success,
    this.headerVersion,
    this.bodyVersion,
    this.error,
    this.currentHeaderVersion,
    this.currentBodyVersion,
    this.currentHeader,
    this.currentBody,
  });

  factory ArtifactUpdateResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    return ArtifactUpdateResponse(
      success: success,
      headerVersion: json['headerVersion'] as int?,
      bodyVersion: json['bodyVersion'] as int?,
      error: json['error'] as String?,
      currentHeaderVersion: json['currentHeaderVersion'] as int?,
      currentBodyVersion: json['currentBodyVersion'] as int?,
      currentHeader: json['currentHeader'] as String?,
      currentBody: json['currentBody'] as String?,
    );
  }
  final bool success;
  final int? headerVersion;
  final int? bodyVersion;
  final String? error;
  final int? currentHeaderVersion;
  final int? currentBodyVersion;
  final String? currentHeader;
  final String? currentBody;

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'headerVersion': headerVersion,
      'bodyVersion': bodyVersion,
      'error': error,
      'currentHeaderVersion': currentHeaderVersion,
      'currentBodyVersion': currentBodyVersion,
      'currentHeader': currentHeader,
      'currentBody': currentBody,
    };
  }
}

/// Artifact folder for organization
class ArtifactFolder {

  ArtifactFolder({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  factory ArtifactFolder.fromJson(Map<String, dynamic> json) {
    return ArtifactFolder(
      id: _asApiString(json['id'], 'id'),
      sessionId: _asApiString(json['sessionId'], 'sessionId'),
      parentId: _asApiStringOptional(json['parentId']),
      name: _asApiString(json['name'], 'name'),
      createdAt: _asApiInt(json['createdAt'], 'createdAt'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
    );
  }
  final String id;
  final String sessionId;
  final String? parentId;
  final String name;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'parentId': parentId,
      'name': name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
