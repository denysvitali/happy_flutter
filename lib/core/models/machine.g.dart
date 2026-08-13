// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MachineMetadata _$MachineMetadataFromJson(Map<String, dynamic> json) =>
    _MachineMetadata(
      host: _asApiStringNullable(json['host']),
      platform: _asApiStringNullable(json['platform']),
      happyCliVersion: _asApiStringNullable(json['happyCliVersion']),
      happyHomeDir: _asApiStringNullable(json['happyHomeDir']),
      homeDir: _asApiStringNullable(json['homeDir']),
      username: _asApiStringNullable(json['username']),
      arch: _asApiStringNullable(json['arch']),
      displayName: _asApiStringNullable(json['displayName']),
      daemonLastKnownStatus: _asApiStringNullable(
        json['daemonLastKnownStatus'],
      ),
      daemonLastKnownPid: _asApiIntNullable(json['daemonLastKnownPid']),
      shutdownRequestedAt: _asApiIntNullable(json['shutdownRequestedAt']),
      shutdownSource: _asApiStringNullable(json['shutdownSource']),
      spawnBackends: _stringListOrNull(json['spawnBackends']),
      defaultSpawnBackend: _asApiStringNullable(json['defaultSpawnBackend']),
      kubernetesCheckoutBaseDir: _asApiStringNullable(
        json['kubernetesCheckoutBaseDir'],
      ),
      sandboxBackend: _asApiStringNullable(json['sandboxBackend']),
      sandboxAvailable: _asApiBoolNullable(json['sandboxAvailable']),
      sandboxEnabled: _asApiBoolNullable(json['sandboxEnabled']),
      sandboxReason: _asApiStringNullable(json['sandboxReason']),
    );

Map<String, dynamic> _$MachineMetadataToJson(_MachineMetadata instance) =>
    <String, dynamic>{
      'host': instance.host,
      'platform': instance.platform,
      'happyCliVersion': instance.happyCliVersion,
      'happyHomeDir': instance.happyHomeDir,
      'homeDir': instance.homeDir,
      'username': instance.username,
      'arch': instance.arch,
      'displayName': instance.displayName,
      'daemonLastKnownStatus': instance.daemonLastKnownStatus,
      'daemonLastKnownPid': instance.daemonLastKnownPid,
      'shutdownRequestedAt': instance.shutdownRequestedAt,
      'shutdownSource': instance.shutdownSource,
      'spawnBackends': instance.spawnBackends,
      'defaultSpawnBackend': instance.defaultSpawnBackend,
      'kubernetesCheckoutBaseDir': instance.kubernetesCheckoutBaseDir,
      'sandboxBackend': instance.sandboxBackend,
      'sandboxAvailable': instance.sandboxAvailable,
      'sandboxEnabled': instance.sandboxEnabled,
      'sandboxReason': instance.sandboxReason,
    };

_Machine _$MachineFromJson(Map<String, dynamic> json) => _Machine(
  id: _machineIdFromJson(json['id']),
  seq: _asApiInt(json['seq']),
  createdAt: _asApiInt(json['createdAt']),
  updatedAt: _asApiInt(json['updatedAt']),
  active: _asBool(json['active']),
  activeAt: _asApiInt(json['activeAt']),
  metadataVersion: _asApiInt(json['metadataVersion']),
  daemonStateVersion: _asApiInt(json['daemonStateVersion']),
  metadata: _machineMetadataFromJson(json['metadata']),
  daemonState: _mapOrNull(json['daemonState']),
);

Map<String, dynamic> _$MachineToJson(_Machine instance) => <String, dynamic>{
  'id': instance.id,
  'seq': instance.seq,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'active': instance.active,
  'activeAt': instance.activeAt,
  'metadataVersion': instance.metadataVersion,
  'daemonStateVersion': instance.daemonStateVersion,
  'metadata': _machineMetadataToJson(instance.metadata),
  'daemonState': instance.daemonState,
};

_GitStatus _$GitStatusFromJson(Map<String, dynamic> json) => _GitStatus(
  isDirty: json['isDirty'] as bool,
  modifiedCount: (json['modifiedCount'] as num).toInt(),
  untrackedCount: (json['untrackedCount'] as num).toInt(),
  stagedCount: (json['stagedCount'] as num).toInt(),
  lastUpdatedAt: (json['lastUpdatedAt'] as num).toInt(),
  branch: json['branch'] as String?,
  stagedLinesAdded: (json['stagedLinesAdded'] as num?)?.toInt() ?? 0,
  stagedLinesRemoved: (json['stagedLinesRemoved'] as num?)?.toInt() ?? 0,
  unstagedLinesAdded: (json['unstagedLinesAdded'] as num?)?.toInt() ?? 0,
  unstagedLinesRemoved: (json['unstagedLinesRemoved'] as num?)?.toInt() ?? 0,
  linesAdded: (json['linesAdded'] as num?)?.toInt() ?? 0,
  linesRemoved: (json['linesRemoved'] as num?)?.toInt() ?? 0,
  linesChanged: (json['linesChanged'] as num?)?.toInt() ?? 0,
  upstreamBranch: json['upstreamBranch'] as String?,
  aheadCount: (json['aheadCount'] as num?)?.toInt(),
  behindCount: (json['behindCount'] as num?)?.toInt(),
  stashCount: (json['stashCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$GitStatusToJson(_GitStatus instance) =>
    <String, dynamic>{
      'isDirty': instance.isDirty,
      'modifiedCount': instance.modifiedCount,
      'untrackedCount': instance.untrackedCount,
      'stagedCount': instance.stagedCount,
      'lastUpdatedAt': instance.lastUpdatedAt,
      'branch': instance.branch,
      'stagedLinesAdded': instance.stagedLinesAdded,
      'stagedLinesRemoved': instance.stagedLinesRemoved,
      'unstagedLinesAdded': instance.unstagedLinesAdded,
      'unstagedLinesRemoved': instance.unstagedLinesRemoved,
      'linesAdded': instance.linesAdded,
      'linesRemoved': instance.linesRemoved,
      'linesChanged': instance.linesChanged,
      'upstreamBranch': instance.upstreamBranch,
      'aheadCount': instance.aheadCount,
      'behindCount': instance.behindCount,
      'stashCount': instance.stashCount,
    };
