/// User profile model
/// Matches React Native schema from sources/sync/profile.ts
class Profile {
  final String id;
  final int timestamp;
  final String? firstName;
  final String? lastName;
  final ImageRef? avatar;
  final GitHubProfile? github;
  final List<String> connectedServices;

  const Profile({
    required this.id,
    this.timestamp = 0,
    this.firstName,
    this.lastName,
    this.avatar,
    this.github,
    this.connectedServices = const [],
  });

  /// Display name - prefers name over github
  String? get displayName {
    if (firstName != null || lastName != null) {
      return [firstName, lastName].where((s) => s != null).join(' ');
    }
    return github?.name ?? github?.login;
  }

  /// Get avatar URL from ImageRef or GitHub
  String? get avatarUrl {
    return avatar?.url ?? github?.avatarUrl;
  }

  /// Get bio from GitHub profile
  String? get bio => github?.bio;

  Profile copyWith({
    String? id,
    int? timestamp,
    String? firstName,
    String? lastName,
    ImageRef? avatar,
    GitHubProfile? github,
    List<String>? connectedServices,
  }) {
    return Profile(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatar: avatar ?? this.avatar,
      github: github ?? this.github,
      connectedServices: connectedServices ?? this.connectedServices,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int? ?? 0,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatar: json['avatar'] != null
          ? ImageRef.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      github: json['github'] != null
          ? GitHubProfile.fromJson(json['github'] as Map<String, dynamic>)
          : null,
      connectedServices: (json['connectedServices'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'firstName': firstName,
      'lastName': lastName,
      'avatar': avatar?.toJson(),
      'github': github?.toJson(),
      'connectedServices': connectedServices,
    };
  }

  /// Default profile
  static const defaults = Profile(id: '');

  /// Parse profile with fallback to defaults
  static Profile parse(dynamic profile) {
    if (profile is Map<String, dynamic>) {
      try {
        return Profile.fromJson(profile);
      } catch (_) {
        return const Profile(id: '');
      }
    }
    return const Profile(id: '');
  }
}

/// Image reference for avatars
/// Matches React Native schema from sources/sync/profile.ts
class ImageRef {
  final int width;
  final int height;
  final String thumbhash;
  final String path;
  final String url;

  const ImageRef({
    required this.width,
    required this.height,
    required this.thumbhash,
    required this.path,
    required this.url,
  });

  factory ImageRef.fromJson(Map<String, dynamic> json) {
    return ImageRef(
      width: json['width'] as int,
      height: json['height'] as int,
      thumbhash: json['thumbhash'] as String,
      path: json['path'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'thumbhash': thumbhash,
      'path': path,
      'url': url,
    };
  }

  ImageRef copyWith({
    int? width,
    int? height,
    String? thumbhash,
    String? path,
    String? url,
  }) {
    return ImageRef(
      width: width ?? this.width,
      height: height ?? this.height,
      thumbhash: thumbhash ?? this.thumbhash,
      path: path ?? this.path,
      url: url ?? this.url,
    );
  }
}

/// GitHub profile information
/// Matches React Native schema from sources/sync/profile.ts
class GitHubProfile {
  final int id;
  final String login;
  final String name;
  final String avatarUrl;
  final String? email;
  final String? bio;

  const GitHubProfile({
    required this.id,
    required this.login,
    required this.name,
    required this.avatarUrl,
    this.email,
    this.bio,
  });

  factory GitHubProfile.fromJson(Map<String, dynamic> json) {
    return GitHubProfile(
      id: json['id'] as int,
      login: json['login'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'name': name,
      'avatar_url': avatarUrl,
      'email': email,
      'bio': bio,
    };
  }

  GitHubProfile copyWith({
    int? id,
    String? login,
    String? name,
    String? avatarUrl,
    String? email,
    String? bio,
  }) {
    return GitHubProfile(
      id: id ?? this.id,
      login: login ?? this.login,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bio: bio ?? this.bio,
    );
  }

  /// Display name - prefer name over login
  String get displayName => name;

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
