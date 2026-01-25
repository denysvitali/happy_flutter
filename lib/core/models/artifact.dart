/// Artifact models for encrypted content storage
/// Matches React Native implementation in ../happy/sources/sync/artifactTypes.ts

/// Encrypted artifact from API (matches React Native Artifact interface)
class Artifact {
  final String id;
  final String header; // Base64 encoded encrypted JSON { "title": string | null }
  final int headerVersion;
  final String? body; // Base64 encoded encrypted JSON { "body": string | null } - only in full fetch
  final int? bodyVersion; // Only in full fetch
  final String dataEncryptionKey; // Base64 encoded encryption key (encrypted with user key)
  final int seq;
  final int createdAt;
  final int updatedAt;

  Artifact({
    required this.id,
    required this.header,
    required this.headerVersion,
    this.body,
    this.bodyVersion,
    required this.dataEncryptionKey,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String,
      header: json['header'] as String,
      headerVersion: json['headerVersion'] as int,
      body: json['body'] as String?,
      bodyVersion: json['bodyVersion'] as int?,
      dataEncryptionKey: json['dataEncryptionKey'] as String,
      seq: json['seq'] as int,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

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
}

/// Decrypted artifact header (matches React Native ArtifactHeader interface)
class ArtifactHeader {
  final String? title;
  final List<String>? sessions; // Optional array of session IDs linked to this artifact
  final bool? draft; // Optional draft flag - hides artifact from visible list when true

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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sessions': sessions,
      'draft': draft,
    };
  }
}

/// Decrypted artifact body (matches React Native ArtifactBody interface)
class ArtifactBody {
  final String? body;

  ArtifactBody({this.body});

  factory ArtifactBody.fromJson(Map<String, dynamic> json) {
    return ArtifactBody(
      body: json['body'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'body': body,
    };
  }
}

/// Decrypted artifact for UI (matches React Native DecryptedArtifact interface)
class DecryptedArtifact {
  final String id;
  final String? title;
  final List<String>? sessions; // Optional array of session IDs linked to this artifact
  final bool? draft; // Optional draft flag - hides artifact from visible list when true
  final String? body; // Only loaded when viewing full artifact
  final int headerVersion;
  final int? bodyVersion;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final bool isDecrypted; // Whether decryption was successful

  DecryptedArtifact({
    required this.id,
    this.title,
    this.sessions,
    this.draft,
    this.body,
    required this.headerVersion,
    this.bodyVersion,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    this.isDecrypted = true,
  });

  factory DecryptedArtifact.fromJson(Map<String, dynamic> json) {
    return DecryptedArtifact(
      id: json['id'] as String,
      title: json['title'] as String?,
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      draft: json['draft'] as bool?,
      body: json['body'] as String?,
      headerVersion: json['headerVersion'] as int,
      bodyVersion: json['bodyVersion'] as int?,
      seq: json['seq'] as int,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      isDecrypted: json['isDecrypted'] as bool? ?? true,
    );
  }

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

  /// Create a decrypted artifact from encrypted artifact and its decrypted parts
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
      sessions: sessions ?? this.sessions,
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
}

/// Request to create a new artifact (matches React Native ArtifactCreateRequest)
class ArtifactCreateRequest {
  final String id; // UUID generated client-side
  final String header; // Base64 encoded encrypted header
  final String body; // Base64 encoded encrypted body
  final String dataEncryptionKey; // Base64 encoded encryption key (encrypted with user key)

  ArtifactCreateRequest({
    required this.id,
    required this.header,
    required this.body,
    required this.dataEncryptionKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'body': body,
      'dataEncryptionKey': dataEncryptionKey,
    };
  }
}

/// Request to update an existing artifact (matches React Native ArtifactUpdateRequest)
class ArtifactUpdateRequest {
  final String? header; // Base64 encoded encrypted header
  final int? expectedHeaderVersion;
  final String? body; // Base64 encoded encrypted body
  final int? expectedBodyVersion;

  ArtifactUpdateRequest({
    this.header,
    this.expectedHeaderVersion,
    this.body,
    this.expectedBodyVersion,
  });

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
  final bool success;
  final int? headerVersion;
  final int? bodyVersion;
  final String? error;
  final int? currentHeaderVersion;
  final int? currentBodyVersion;
  final String? currentHeader;
  final String? currentBody;

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
  final String id;
  final String sessionId;
  final String? parentId;
  final String name;
  final int createdAt;
  final int updatedAt;

  ArtifactFolder({
    required this.id,
    required this.sessionId,
    this.parentId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArtifactFolder.fromJson(Map<String, dynamic> json) {
    return ArtifactFolder(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      parentId: json['parentId'] as String?,
      name: json['name'] as String,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

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
