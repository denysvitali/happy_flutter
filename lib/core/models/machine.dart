/// Machine metadata schema
class MachineMetadata {
  final String host;
  final String platform;
  final String happyCliVersion;
  final String happyHomeDir;
  final String homeDir;
  final String? username;
  final String? arch;
  final String? displayName;
  final String? daemonLastKnownStatus;
  final int? daemonLastKnownPid;
  final int? shutdownRequestedAt;
  final String? shutdownSource;

  MachineMetadata({
    required this.host,
    required this.platform,
    required this.happyCliVersion,
    required this.happyHomeDir,
    required this.homeDir,
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
      host: json['host'] as String,
      platform: json['platform'] as String,
      happyCliVersion: json['happyCliVersion'] as String,
      happyHomeDir: json['happyHomeDir'] as String,
      homeDir: json['homeDir'] as String,
      username: json['username'] as String?,
      arch: json['arch'] as String?,
      displayName: json['displayName'] as String?,
      daemonLastKnownStatus: json['daemonLastKnownStatus'] as String?,
      daemonLastKnownPid: json['daemonLastKnownPid'] as int?,
      shutdownRequestedAt: json['shutdownRequestedAt'] as int?,
      shutdownSource: json['shutdownSource'] as String?,
    );
  }

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
}

/// Machine model
class Machine {
  final String id;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final bool active;
  final int activeAt;
  final MachineMetadata? metadata;
  final int metadataVersion;
  final dynamic daemonState;
  final int daemonStateVersion;

  Machine({
    required this.id,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    required this.active,
    required this.activeAt,
    this.metadata,
    required this.metadataVersion,
    this.daemonState,
    required this.daemonStateVersion,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      seq: json['seq'] as int,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      active: json['active'] as bool,
      activeAt: json['activeAt'] as int,
      metadata: json['metadata'] != null
          ? MachineMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      metadataVersion: json['metadataVersion'] as int,
      daemonState: json['daemonState'],
      daemonStateVersion: json['daemonStateVersion'] as int,
    );
  }

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
}

/// Git status model
class GitStatus {
  final String? branch;
  final bool isDirty;
  final int modifiedCount;
  final int untrackedCount;
  final int stagedCount;
  final int lastUpdatedAt;
  int stagedLinesAdded = 0;
  int stagedLinesRemoved = 0;
  int unstagedLinesAdded = 0;
  int unstagedLinesRemoved = 0;
  int linesAdded = 0;
  int linesRemoved = 0;
  int linesChanged = 0;
  final String? upstreamBranch;
  final int? aheadCount;
  final int? behindCount;
  final int? stashCount;

  GitStatus({
    this.branch,
    required this.isDirty,
    required this.modifiedCount,
    required this.untrackedCount,
    required this.stagedCount,
    required this.lastUpdatedAt,
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
}
