/// Artifact models for encrypted content storage

/// Encrypted artifact stored on server
class Artifact {
  final String id;
  final String sessionId;
  final String? parentId;
  final String type; // 'file', 'image', 'text', 'code'
  final String mimeType;
  final String? fileName;
  final int fileSize;
  final String? digest;
  final int createdAt;
  final int updatedAt;
  final bool encrypted;
  final String encryptionKeyId;

  Artifact({
    required this.id,
    required this.sessionId,
    this.parentId,
    required this.type,
    required this.mimeType,
    this.fileName,
    required this.fileSize,
    this.digest,
    required this.createdAt,
    required this.updatedAt,
    this.encrypted = true,
    required this.encryptionKeyId,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      parentId: json['parentId'] as String?,
      type: json['type'] as String,
      mimeType: json['mimeType'] as String,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int,
      digest: json['digest'] as String?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      encrypted: json['encrypted'] as bool? ?? true,
      encryptionKeyId: json['encryptionKeyId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'parentId': parentId,
      'type': type,
      'mimeType': mimeType,
      'fileName': fileName,
      'fileSize': fileSize,
      'digest': digest,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'encrypted': encrypted,
      'encryptionKeyId': encryptionKeyId,
    };
  }
}

/// Decrypted artifact with content
class DecryptedArtifact {
  final Artifact artifact;
  final String content;
  final String? plainText;
  final int decryptedAt;

  DecryptedArtifact({
    required this.artifact,
    required this.content,
    this.plainText,
    required this.decryptedAt,
  });

  factory DecryptedArtifact.fromJson(Map<String, dynamic> json) {
    return DecryptedArtifact(
      artifact: Artifact.fromJson(json['artifact'] as Map<String, dynamic>),
      content: json['content'] as String,
      plainText: json['plainText'] as String?,
      decryptedAt: json['decryptedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artifact': artifact.toJson(),
      'content': content,
      'plainText': plainText,
      'decryptedAt': decryptedAt,
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
