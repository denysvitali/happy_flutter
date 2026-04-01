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

bool _asApiBool(dynamic value, String fieldName) {
  if (value is bool) return value;
  throw FormatException(
    'Expected bool for $fieldName, got ${value.runtimeType}',
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

/// Machine metadata schema
class MachineMetadata {
  MachineMetadata({
    this.host,
    this.platform,
    this.happyCliVersion,
    this.happyHomeDir,
    this.homeDir,
    this.username,
    this.arch,
    this.displayName,
    this.daemonLastKnownStatus,
    this.daemonLastKnownPid,
    this.shutdownRequestedAt,
    this.shutdownSource,
  });

  factory MachineMetadata.fromJson(Map<String, dynamic> json) {
    return MachineMetadata(
      host: _asApiStringOptional(json['host']),
      platform: _asApiStringOptional(json['platform']),
      happyCliVersion: _asApiStringOptional(json['happyCliVersion']),
      happyHomeDir: _asApiStringOptional(json['happyHomeDir']),
      homeDir: _asApiStringOptional(json['homeDir']),
      username: _asApiStringOptional(json['username']),
      arch: _asApiStringOptional(json['arch']),
      displayName: _asApiStringOptional(json['displayName']),
      daemonLastKnownStatus: _asApiStringOptional(
        json['daemonLastKnownStatus'],
      ),
      daemonLastKnownPid: _asApiIntOptional(json['daemonLastKnownPid']),
      shutdownRequestedAt: _asApiIntOptional(json['shutdownRequestedAt']),
      shutdownSource: _asApiStringOptional(json['shutdownSource']),
    );
  }
  final String? host;
  final String? platform;
  final String? happyCliVersion;
  final String? happyHomeDir;
  final String? homeDir;
  final String? username;
  final String? arch;
  final String? displayName;
  final String? daemonLastKnownStatus;
  final int? daemonLastKnownPid;
  final int? shutdownRequestedAt;
  final String? shutdownSource;

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'platform': platform,
      'happyCliVersion': happyCliVersion,
      'happyHomeDir': happyHomeDir,
      'homeDir': homeDir,
      'username': username,
      'arch': arch,
      'displayName': displayName,
      'daemonLastKnownStatus': daemonLastKnownStatus,
      'daemonLastKnownPid': daemonLastKnownPid,
      'shutdownRequestedAt': shutdownRequestedAt,
      'shutdownSource': shutdownSource,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineMetadata &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          platform == other.platform &&
          happyCliVersion == other.happyCliVersion &&
          happyHomeDir == other.happyHomeDir &&
          homeDir == other.homeDir &&
          username == other.username &&
          arch == other.arch &&
          displayName == other.displayName &&
          daemonLastKnownStatus == other.daemonLastKnownStatus &&
          daemonLastKnownPid == other.daemonLastKnownPid &&
          shutdownRequestedAt == other.shutdownRequestedAt &&
          shutdownSource == other.shutdownSource;

  @override
  int get hashCode => Object.hash(
    host,
    platform,
    happyCliVersion,
    happyHomeDir,
    homeDir,
    username,
    arch,
    displayName,
    daemonLastKnownStatus,
    daemonLastKnownPid,
    shutdownRequestedAt,
    shutdownSource,
  );
}

/// Machine model
class Machine {
  Machine({
    required this.id,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    required this.active,
    required this.activeAt,
    required this.metadataVersion,
    required this.daemonStateVersion,
    this.metadata,
    this.daemonState,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: _asApiString(json['id'], 'id'),
      seq: _asApiInt(json['seq'], 'seq'),
      createdAt: _asApiInt(json['createdAt'], 'createdAt'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
      active: _asApiBool(json['active'], 'active'),
      activeAt: _asApiInt(json['activeAt'], 'activeAt'),
      metadata: json['metadata'] != null
          ? MachineMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      metadataVersion: _asApiInt(json['metadataVersion'], 'metadataVersion'),
      daemonState: json['daemonState'] as Map<String, dynamic>?,
      daemonStateVersion: _asApiInt(
        json['daemonStateVersion'],
        'daemonStateVersion',
      ),
    );
  }
  final String id;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final bool active;
  final int activeAt;
  final MachineMetadata? metadata;
  final int metadataVersion;
  final Map<String, dynamic>? daemonState;
  final int daemonStateVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'active': active,
      'activeAt': activeAt,
      'metadata': metadata?.toJson(),
      'metadataVersion': metadataVersion,
      'daemonState': daemonState,
      'daemonStateVersion': daemonStateVersion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          seq == other.seq &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          active == other.active &&
          activeAt == other.activeAt &&
          metadata == other.metadata &&
          metadataVersion == other.metadataVersion &&
          daemonState == other.daemonState &&
          daemonStateVersion == other.daemonStateVersion;

  @override
  int get hashCode => Object.hash(
    id,
    seq,
    createdAt,
    updatedAt,
    active,
    activeAt,
    metadata,
    metadataVersion,
    daemonState,
    daemonStateVersion,
  );

  Machine copyWith({
    String? id,
    int? seq,
    int? createdAt,
    int? updatedAt,
    bool? active,
    int? activeAt,
    MachineMetadata? metadata,
    int? metadataVersion,
    Map<String, dynamic>? daemonState,
    int? daemonStateVersion,
  }) {
    return Machine(
      id: id ?? this.id,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      active: active ?? this.active,
      activeAt: activeAt ?? this.activeAt,
      metadata: metadata ?? this.metadata,
      metadataVersion: metadataVersion ?? this.metadataVersion,
      daemonState: daemonState ?? this.daemonState,
      daemonStateVersion: daemonStateVersion ?? this.daemonStateVersion,
    );
  }
}

/// Git status model
class GitStatus {
  GitStatus({
    required this.isDirty,
    required this.modifiedCount,
    required this.untrackedCount,
    required this.stagedCount,
    required this.lastUpdatedAt,
    this.branch,
    this.stagedLinesAdded = 0,
    this.stagedLinesRemoved = 0,
    this.unstagedLinesAdded = 0,
    this.unstagedLinesRemoved = 0,
    this.linesAdded = 0,
    this.linesRemoved = 0,
    this.linesChanged = 0,
    this.upstreamBranch,
    this.aheadCount,
    this.behindCount,
    this.stashCount,
  });

  factory GitStatus.fromJson(Map<String, dynamic> json) {
    return GitStatus(
      branch: json['branch'] as String?,
      isDirty: json['isDirty'] as bool,
      modifiedCount: json['modifiedCount'] as int,
      untrackedCount: json['untrackedCount'] as int,
      stagedCount: json['stagedCount'] as int,
      lastUpdatedAt: json['lastUpdatedAt'] as int,
      stagedLinesAdded: json['stagedLinesAdded'] as int? ?? 0,
      stagedLinesRemoved: json['stagedLinesRemoved'] as int? ?? 0,
      unstagedLinesAdded: json['unstagedLinesAdded'] as int? ?? 0,
      unstagedLinesRemoved: json['unstagedLinesRemoved'] as int? ?? 0,
      linesAdded: json['linesAdded'] as int? ?? 0,
      linesRemoved: json['linesRemoved'] as int? ?? 0,
      linesChanged: json['linesChanged'] as int? ?? 0,
      upstreamBranch: json['upstreamBranch'] as String?,
      aheadCount: json['aheadCount'] as int?,
      behindCount: json['behindCount'] as int?,
      stashCount: json['stashCount'] as int?,
    );
  }
  final String? branch;
  final bool isDirty;
  final int modifiedCount;
  final int untrackedCount;
  final int stagedCount;
  final int lastUpdatedAt;
  final int stagedLinesAdded;
  final int stagedLinesRemoved;
  final int unstagedLinesAdded;
  final int unstagedLinesRemoved;
  final int linesAdded;
  final int linesRemoved;
  final int linesChanged;
  final String? upstreamBranch;
  final int? aheadCount;
  final int? behindCount;
  final int? stashCount;

  Map<String, dynamic> toJson() {
    return {
      'branch': branch,
      'isDirty': isDirty,
      'modifiedCount': modifiedCount,
      'untrackedCount': untrackedCount,
      'stagedCount': stagedCount,
      'lastUpdatedAt': lastUpdatedAt,
      'stagedLinesAdded': stagedLinesAdded,
      'stagedLinesRemoved': stagedLinesRemoved,
      'unstagedLinesAdded': unstagedLinesAdded,
      'unstagedLinesRemoved': unstagedLinesRemoved,
      'linesAdded': linesAdded,
      'linesRemoved': linesRemoved,
      'linesChanged': linesChanged,
      'upstreamBranch': upstreamBranch,
      'aheadCount': aheadCount,
      'behindCount': behindCount,
      'stashCount': stashCount,
    };
  }

  GitStatus copyWith({
    String? branch,
    bool? isDirty,
    int? modifiedCount,
    int? untrackedCount,
    int? stagedCount,
    int? lastUpdatedAt,
    int? stagedLinesAdded,
    int? stagedLinesRemoved,
    int? unstagedLinesAdded,
    int? unstagedLinesRemoved,
    int? linesAdded,
    int? linesRemoved,
    int? linesChanged,
    String? upstreamBranch,
    int? aheadCount,
    int? behindCount,
    int? stashCount,
  }) {
    return GitStatus(
      branch: branch ?? this.branch,
      isDirty: isDirty ?? this.isDirty,
      modifiedCount: modifiedCount ?? this.modifiedCount,
      untrackedCount: untrackedCount ?? this.untrackedCount,
      stagedCount: stagedCount ?? this.stagedCount,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      stagedLinesAdded: stagedLinesAdded ?? this.stagedLinesAdded,
      stagedLinesRemoved: stagedLinesRemoved ?? this.stagedLinesRemoved,
      unstagedLinesAdded: unstagedLinesAdded ?? this.unstagedLinesAdded,
      unstagedLinesRemoved: unstagedLinesRemoved ?? this.unstagedLinesRemoved,
      linesAdded: linesAdded ?? this.linesAdded,
      linesRemoved: linesRemoved ?? this.linesRemoved,
      linesChanged: linesChanged ?? this.linesChanged,
      upstreamBranch: upstreamBranch ?? this.upstreamBranch,
      aheadCount: aheadCount ?? this.aheadCount,
      behindCount: behindCount ?? this.behindCount,
      stashCount: stashCount ?? this.stashCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitStatus &&
          runtimeType == other.runtimeType &&
          branch == other.branch &&
          isDirty == other.isDirty &&
          modifiedCount == other.modifiedCount &&
          untrackedCount == other.untrackedCount &&
          stagedCount == other.stagedCount &&
          lastUpdatedAt == other.lastUpdatedAt &&
          stagedLinesAdded == other.stagedLinesAdded &&
          stagedLinesRemoved == other.stagedLinesRemoved &&
          unstagedLinesAdded == other.unstagedLinesAdded &&
          unstagedLinesRemoved == other.unstagedLinesRemoved &&
          linesAdded == other.linesAdded &&
          linesRemoved == other.linesRemoved &&
          linesChanged == other.linesChanged &&
          upstreamBranch == other.upstreamBranch &&
          aheadCount == other.aheadCount &&
          behindCount == other.behindCount &&
          stashCount == other.stashCount;

  @override
  int get hashCode => Object.hash(
    branch,
    isDirty,
    modifiedCount,
    untrackedCount,
    stagedCount,
    lastUpdatedAt,
    stagedLinesAdded,
    stagedLinesRemoved,
    unstagedLinesAdded,
    unstagedLinesRemoved,
    linesAdded,
    linesRemoved,
    linesChanged,
    upstreamBranch,
    aheadCount,
    behindCount,
    stashCount,
  );
}
