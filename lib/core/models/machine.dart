import 'package:freezed_annotation/freezed_annotation.dart';

part 'machine.freezed.dart';
part 'machine.g.dart';

int _asApiInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

int? _asApiIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

String? _asApiStringNullable(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return null;
}

List<String>? _stringListOrNull(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  return null;
}

MachineMetadata? _machineMetadataFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MachineMetadata.fromJson(value);
  }
  return null;
}

Map<String, dynamic>? _machineMetadataToJson(MachineMetadata? value) =>
    value?.toJson();

bool _asBool(dynamic value) {
  if (value is bool) return value;
  throw FormatException('Expected bool, got ${value.runtimeType}');
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

/// Machine metadata schema
@freezed
abstract class MachineMetadata with _$MachineMetadata {
  const factory MachineMetadata({
    @JsonKey(fromJson: _asApiStringNullable) String? host,
    @JsonKey(fromJson: _asApiStringNullable) String? platform,
    @JsonKey(fromJson: _asApiStringNullable) String? happyCliVersion,
    @JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,
    @JsonKey(fromJson: _asApiStringNullable) String? homeDir,
    @JsonKey(fromJson: _asApiStringNullable) String? username,
    @JsonKey(fromJson: _asApiStringNullable) String? arch,
    @JsonKey(fromJson: _asApiStringNullable) String? displayName,
    @JsonKey(fromJson: _asApiStringNullable) String? daemonLastKnownStatus,
    @JsonKey(fromJson: _asApiIntNullable) int? daemonLastKnownPid,
    @JsonKey(fromJson: _asApiIntNullable) int? shutdownRequestedAt,
    @JsonKey(fromJson: _asApiStringNullable) String? shutdownSource,
    @JsonKey(fromJson: _stringListOrNull) List<String>? spawnBackends,
    @JsonKey(fromJson: _asApiStringNullable) String? defaultSpawnBackend,
  }) = _MachineMetadata;

  factory MachineMetadata.fromJson(Map<String, dynamic> json) =>
      _$MachineMetadataFromJson(json);
}

/// Machine model
@freezed
abstract class Machine with _$Machine {
  const factory Machine({
    @JsonKey(fromJson: _machineIdFromJson) required String id,
    @JsonKey(fromJson: _asApiInt) required int seq,
    @JsonKey(fromJson: _asApiInt) required int createdAt,
    @JsonKey(fromJson: _asApiInt) required int updatedAt,
    @JsonKey(fromJson: _asBool) required bool active,
    @JsonKey(fromJson: _asApiInt) required int activeAt,
    @JsonKey(fromJson: _asApiInt) required int metadataVersion,
    @JsonKey(fromJson: _asApiInt) required int daemonStateVersion,
    @JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson)
    MachineMetadata? metadata,
    @JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? daemonState,
  }) = _Machine;

  factory Machine.fromJson(Map<String, dynamic> json) =>
      _$MachineFromJson(json);
}

String _machineIdFromJson(dynamic value) {
  if (value is String) return value;
  throw FormatException('Expected String for id, got ${value.runtimeType}');
}

/// Maximum accepted age for a machine heartbeat when deciding whether the
/// machine is available for user actions.
const int machineOnlineThresholdMs = 120 * 1000;

/// Client-side online check used by UI screens and spawn guards.
///
/// A machine is online only when the server explicitly says so ([active]) and
/// the last activity timestamp is still fresh. Checking only [active], or only
/// [activeAt], makes screens and create-session guards disagree.
extension MachineOnline on Machine {
  bool get isOnline {
    final now = DateTime.now().millisecondsSinceEpoch;
    return isOnlineAt(now);
  }

  String get displayLabel {
    final meta = metadata;
    return meta?.displayName ?? meta?.host ?? id;
  }

  bool isOnlineAt(int nowMs) =>
      active && nowMs - activeAt < machineOnlineThresholdMs;

  bool isStaleAt(int nowMs) =>
      active && nowMs - activeAt >= machineOnlineThresholdMs;
}

int compareMachinesByAvailability(Machine a, Machine b) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return compareMachinesByAvailabilityAt(now, a, b);
}

int compareMachinesByAvailabilityAt(int nowMs, Machine a, Machine b) {
  final aOffline = a.isOnlineAt(nowMs) ? 0 : 1;
  final bOffline = b.isOnlineAt(nowMs) ? 0 : 1;
  if (aOffline != bOffline) return aOffline.compareTo(bOffline);

  final labelComparison = a.displayLabel.compareTo(b.displayLabel);
  if (labelComparison != 0) return labelComparison;

  return a.id.compareTo(b.id);
}

/// Git status model
@freezed
abstract class GitStatus with _$GitStatus {
  const factory GitStatus({
    required bool isDirty,
    required int modifiedCount,
    required int untrackedCount,
    required int stagedCount,
    required int lastUpdatedAt,
    String? branch,
    @Default(0) int stagedLinesAdded,
    @Default(0) int stagedLinesRemoved,
    @Default(0) int unstagedLinesAdded,
    @Default(0) int unstagedLinesRemoved,
    @Default(0) int linesAdded,
    @Default(0) int linesRemoved,
    @Default(0) int linesChanged,
    String? upstreamBranch,
    int? aheadCount,
    int? behindCount,
    int? stashCount,
  }) = _GitStatus;

  factory GitStatus.fromJson(Map<String, dynamic> json) =>
      _$GitStatusFromJson(json);
}
