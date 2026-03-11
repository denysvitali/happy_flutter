/// SFTP authentication method
enum SftpAuthMethod {
  password,
  publicKey,
  anonymous,
}

/// Clipboard sync mode for shared directory
enum SftpClipboardMode {
  off,
  bidirectional,
  pushOnly,
  pullOnly,
}

/// A shared SFTP directory
class SftpDirectory {
  const SftpDirectory({
    required this.id,
    required this.name,
    required this.path,
    required this.port,
    required this.authMethod,
    required this.clipboardMode,
    this.remotePath,
    this.isActive = true,
  });

  factory SftpDirectory.fromJson(Map<String, dynamic> json) {
    return SftpDirectory(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      port: json['port'] as int? ?? 22,
      authMethod: SftpAuthMethod.values.firstWhere(
        (e) => e.name == json['authMethod'],
        orElse: () => SftpAuthMethod.password,
      ),
      clipboardMode: SftpClipboardMode.values.firstWhere(
        (e) => e.name == json['clipboardMode'],
        orElse: () => SftpClipboardMode.off,
      ),
      remotePath: json['remotePath'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String path;
  final int port;
  final SftpAuthMethod authMethod;
  final SftpClipboardMode clipboardMode;
  final String? remotePath;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'port': port,
      'authMethod': authMethod.name,
      'clipboardMode': clipboardMode.name,
      if (remotePath != null) 'remotePath': remotePath,
      'isActive': isActive,
    };
  }

  SftpDirectory copyWith({
    String? id,
    String? name,
    String? path,
    int? port,
    SftpAuthMethod? authMethod,
    SftpClipboardMode? clipboardMode,
    String? remotePath,
    bool? isActive,
  }) {
    return SftpDirectory(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      port: port ?? this.port,
      authMethod: authMethod ?? this.authMethod,
      clipboardMode: clipboardMode ?? this.clipboardMode,
      remotePath: remotePath ?? this.remotePath,
      isActive: isActive ?? this.isActive,
    );
  }
}
