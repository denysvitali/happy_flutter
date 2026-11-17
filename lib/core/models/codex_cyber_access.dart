import 'package:flutter/foundation.dart';

/// Daybreak state of a Codex session, as published by happy-cli-go.
enum CodexCyberAccessState {
  /// No program requested: Codex selects automatically, Daybreak is off.
  off,

  /// Requested on every turn and accepted for this account and model.
  active,

  /// Requested on every turn; the model catalog does not confirm acceptance.
  requested,

  /// Requested, but this account/model does not accept it.
  unavailable,

  /// Requested, but the installed Codex cannot send it; turns are refused.
  unsupported,

  /// A state this app version does not know.
  unknown;

  static CodexCyberAccessState parse(Object? value) => switch (value) {
    'off' => off,
    'active' => active,
    'requested' => requested,
    'unavailable' => unavailable,
    'unsupported' => unsupported,
    _ => unknown,
  };
}

/// The session's Codex cybersecurity access program (Daybreak) status.
///
/// happy-cli-go publishes it as `codexCyberAccess` in session metadata.
/// Program names use its snake_case spelling (`daybreak_blue`).
@immutable
class CodexCyberAccess {
  const CodexCyberAccess({
    required this.state,
    this.requested = '',
    this.source = 'machine',
    this.machine = '',
    this.model,
    this.available,
    this.supported,
    this.lastFlaggedAt,
    this.lastReroutedAt,
    this.lastReroutedTo,
    this.verifications = const [],
    this.detail = '',
    this.updatedAt,
  });

  final CodexCyberAccessState state;

  /// The configured program; empty means automatic selection.
  final String requested;

  /// `session` when the app chose the program for this session, otherwise
  /// `machine` (the daemon's configuration).
  final String source;

  /// The daemon's configured program; empty means none.
  final String machine;
  final String? model;

  /// Programs the model catalog accepts for [model]; null when unknown.
  final List<String>? available;
  final bool? supported;
  final int? lastFlaggedAt;
  final int? lastReroutedAt;
  final String? lastReroutedTo;
  final List<String> verifications;

  /// Human-readable explanation written by happy-cli-go.
  final String detail;
  final int? updatedAt;

  /// Whether Daybreak is confirmed on for this session.
  bool get isActive => state == CodexCyberAccessState.active;

  /// Whether the account is eligible for a Daybreak tier on [model].
  bool get eligible =>
      available?.any((program) => program.startsWith('daybreak_')) ?? false;

  static CodexCyberAccess? maybeFromJson(dynamic value) {
    if (value is! Map) return null;
    String? str(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    int? integer(Object? v) => v is num && v > 0 ? v.toInt() : null;
    List<String>? strings(Object? v) => v is List
        ? [
            for (final item in v)
              if (item is String && item.trim().isNotEmpty) item.trim(),
          ]
        : null;
    final supported = value['supported'];
    return CodexCyberAccess(
      state: CodexCyberAccessState.parse(value['state']),
      requested: str(value['requested']) ?? '',
      source: str(value['source']) ?? 'machine',
      machine: str(value['machine']) ?? '',
      model: str(value['model']),
      available: strings(value['available']),
      supported: supported is bool ? supported : null,
      lastFlaggedAt: integer(value['lastFlaggedAt']),
      lastReroutedAt: integer(value['lastReroutedAt']),
      lastReroutedTo: str(value['lastReroutedTo']),
      verifications: strings(value['verifications']) ?? const [],
      detail: str(value['detail']) ?? '',
      updatedAt: integer(value['updatedAt']),
    );
  }

  static dynamic maybeToJson(CodexCyberAccess? value) => value?.toJson();

  Map<String, dynamic> toJson() => {
    'state': state == CodexCyberAccessState.unknown ? 'unknown' : state.name,
    'requested': requested,
    'source': source,
    'machine': machine,
    if (model != null) 'model': model,
    if (available != null) 'available': available,
    if (supported != null) 'supported': supported,
    if (lastFlaggedAt != null) 'lastFlaggedAt': lastFlaggedAt,
    if (lastReroutedAt != null) 'lastReroutedAt': lastReroutedAt,
    if (lastReroutedTo != null) 'lastReroutedTo': lastReroutedTo,
    if (verifications.isNotEmpty) 'verifications': verifications,
    'detail': detail,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexCyberAccess &&
          other.state == state &&
          other.requested == requested &&
          other.source == source &&
          other.machine == machine &&
          other.model == model &&
          listEquals(other.available, available) &&
          other.supported == supported &&
          other.lastFlaggedAt == lastFlaggedAt &&
          other.lastReroutedAt == lastReroutedAt &&
          other.lastReroutedTo == lastReroutedTo &&
          listEquals(other.verifications, verifications) &&
          other.detail == detail &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    state,
    requested,
    source,
    machine,
    model,
    available == null ? null : Object.hashAll(available!),
    supported,
    lastFlaggedAt,
    lastReroutedAt,
    lastReroutedTo,
    Object.hashAll(verifications),
    detail,
    updatedAt,
  );
}
