/// User profile model
class Profile {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GitHubProfile? github;
  final Map<String, dynamic>? rawData;

  Profile({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.github,
    this.rawData,
  });

  /// Display name - prefers name over email
  String get displayName => name ?? email.split('@').first;

  Profile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    GitHubProfile? github,
    Map<String, dynamic>? rawData,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      github: github ?? this.github,
      rawData: rawData ?? this.rawData,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      github: json['github'] != null
          ? GitHubProfile.fromJson(json['github'] as Map<String, dynamic>)
          : null,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'github': github?.toJson(),
    };
  }
}

/// GitHub profile information
class GitHubProfile {
  final String login;
  final int id;
  final String? avatarUrl;
  final String? name;
  final String? email;
  final String? bio;
  final String? htmlUrl;
  final int? publicRepos;
  final int? followers;
  final int? following;
  final bool? isVerified;
  final Map<String, dynamic>? rawData;

  GitHubProfile({
    required this.login,
    required this.id,
    this.avatarUrl,
    this.name,
    this.email,
    this.bio,
    this.htmlUrl,
    this.publicRepos,
    this.followers,
    this.following,
    this.isVerified,
    this.rawData,
  });

  factory GitHubProfile.fromJson(Map<String, dynamic> json) {
    return GitHubProfile(
      login: json['login'] as String,
      id: json['id'] as int,
      avatarUrl: json['avatar_url'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      htmlUrl: json['html_url'] as String?,
      publicRepos: json['public_repos'] as int?,
      followers: json['followers'] as int?,
      following: json['following'] as int?,
      isVerified: json['is_verified'] as bool?,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'id': id,
      'avatar_url': avatarUrl,
      'name': name,
      'email': email,
      'bio': bio,
      'html_url': htmlUrl,
      'public_repos': publicRepos,
      'followers': followers,
      'following': following,
      'is_verified': isVerified,
    };
  }

  /// Display name - prefer name over login
  String get displayName => name ?? login;

  /// Whether the profile has linking info
  bool get hasLinking => login.isNotEmpty && id > 0;
}

/// Connected service provider types
enum ConnectedService {
  claude('Claude', 'https://claude.com'),
  github('GitHub', 'https://github.com'),
  gemini('Gemini', 'https://gemini.google.com'),
  openai('OpenAI', 'https://openai.com');

  final String displayName;
  final String websiteUrl;

  const ConnectedService(this.displayName, this.websiteUrl);
}

/// Represents a connected third-party service
class ConnectedServiceInfo {
  final ConnectedService service;
  final String? accountId;
  final String? accountName;
  final String? accountEmail;
  final String? avatarUrl;
  final bool isConnected;
  final DateTime? connectedAt;

  ConnectedServiceInfo({
    required this.service,
    this.accountId,
    this.accountName,
    this.accountEmail,
    this.avatarUrl,
    this.isConnected = false,
    this.connectedAt,
  });

  factory ConnectedServiceInfo.fromJson(Map<String, dynamic> json) {
    final serviceType = _parseServiceType(json['service'] as String?);

    return ConnectedServiceInfo(
      service: serviceType ?? ConnectedService.claude,
      accountId: json['account_id'] as String?,
      accountName: json['account_name'] as String?,
      accountEmail: json['account_email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isConnected: json['is_connected'] as bool? ?? false,
      connectedAt: json['connected_at'] != null
          ? DateTime.tryParse(json['connected_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service': service.name,
      'account_id': accountId,
      'account_name': accountName,
      'account_email': accountEmail,
      'avatar_url': avatarUrl,
      'is_connected': isConnected,
      'connected_at': connectedAt?.toIso8601String(),
    };
  }

  static ConnectedService? _parseServiceType(String? type) {
    if (type == null) return null;
    return ConnectedService.values.firstWhere(
      (s) => s.name == type.toLowerCase(),
      orElse: () => ConnectedService.claude,
    );
  }
}

/// Device information for linking
class DeviceInfo {
  final String id;
  final String name;
  final String platform;
  final DateTime lastActive;
  final bool isCurrentDevice;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastActive,
    this.isCurrentDevice = false,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      lastActive: DateTime.parse(json['last_active'] as String),
      isCurrentDevice: json['is_current_device'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'last_active': lastActive.toIso8601String(),
      'is_current_device': isCurrentDevice,
    };
  }

  String get platformIcon {
    switch (platform.toLowerCase()) {
      case 'ios':
        return 'phone_iphone';
      case 'android':
        return 'phone_android';
      case 'macos':
        return 'computer';
      case 'windows':
        return 'computer';
      case 'linux':
        return 'computer';
      case 'web':
        return 'language';
      default:
        return 'devices';
    }
  }
}

/// Account backup information
class AccountBackupInfo {
  final bool hasBackup;
  final DateTime? lastBackupAt;
  final String? backupDeviceId;

  AccountBackupInfo({
    this.hasBackup = false,
    this.lastBackupAt,
    this.backupDeviceId,
  });

  factory AccountBackupInfo.fromJson(Map<String, dynamic> json) {
    return AccountBackupInfo(
      hasBackup: json['has_backup'] as bool? ?? false,
      lastBackupAt: json['last_backup_at'] != null
          ? DateTime.tryParse(json['last_backup_at'] as String)
          : null,
      backupDeviceId: json['backup_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_backup': hasBackup,
      'last_backup_at': lastBackupAt?.toIso8601String(),
      'backup_device_id': backupDeviceId,
    };
  }
}

/// Image reference for avatars and attachments
class ImageRef {
  final String url;
  final int? width;
  final int? height;
  final String? mimeType;

  ImageRef({
    required this.url,
    this.width,
    this.height,
    this.mimeType,
  });

  factory ImageRef.fromJson(Map<String, dynamic> json) {
    return ImageRef(
      url: json['url'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'width': width,
      'height': height,
      'mimeType': mimeType,
    };
  }
}
