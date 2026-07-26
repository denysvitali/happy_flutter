/// Models for the per-project sandbox policy a machine daemon exposes over
/// the `sandbox-list` / `sandbox-get` / `sandbox-set` RPCs.
///
/// A sandboxed session sees its own project directory, whatever directories
/// the user granted it here, and the public internet — nothing else on the
/// machine. Sandboxing is opt-out: a project nobody has configured is already
/// sandboxed with only its own directory, and this screen exists for the two
/// exceptions, "this project also needs that folder" and "not this project".
///
/// The policy lives on the machine rather than on the server because every
/// value in it is a path that only means something there.
library;

/// How one granted directory is exposed inside the sandbox.
enum SandboxGrantMode {
  /// The session can read and write the directory.
  readWrite('rw'),

  /// The session can read the directory but not change it.
  readOnly('ro');

  const SandboxGrantMode(this.wire);

  /// The value used on the RPC wire.
  final String wire;

  static SandboxGrantMode fromWire(String? value) {
    for (final mode in SandboxGrantMode.values) {
      if (mode.wire == value) return mode;
    }
    return SandboxGrantMode.readWrite;
  }
}

/// One directory a project's sessions may see beyond the project itself.
class SandboxGrant {
  const SandboxGrant({
    required this.path,
    this.mode = SandboxGrantMode.readWrite,
  });

  factory SandboxGrant.fromJson(Map<dynamic, dynamic> json) => SandboxGrant(
    path: json['path'] as String? ?? '',
    mode: SandboxGrantMode.fromWire(json['mode'] as String?),
  );

  final String path;
  final SandboxGrantMode mode;

  Map<String, dynamic> toJson() => {'path': path, 'mode': mode.wire};

  SandboxGrant copyWith({String? path, SandboxGrantMode? mode}) =>
      SandboxGrant(path: path ?? this.path, mode: mode ?? this.mode);

  @override
  bool operator ==(Object other) =>
      other is SandboxGrant && other.path == path && other.mode == mode;

  @override
  int get hashCode => Object.hash(path, mode);
}

/// The daemon's answer to a sandbox RPC: what the machine can do, plus the
/// policy for the project that was asked about.
class SandboxPolicyResponse {
  const SandboxPolicyResponse({
    required this.success,
    this.machineEnabled = false,
    this.available = false,
    this.backend,
    this.network,
    this.reason,
    this.directory,
    this.enabled,
    this.effectiveEnabled = false,
    this.grants = const [],
    this.allowHosts = const [],
    this.updatedAt,
    this.projects = const [],
    this.error,
  });

  factory SandboxPolicyResponse.fromJson(Map<String, dynamic> json) {
    final rawProjects = json['projects'];
    return SandboxPolicyResponse(
      success: json['success'] as bool? ?? false,
      machineEnabled: json['machineEnabled'] as bool? ?? false,
      available: json['available'] as bool? ?? false,
      backend: _nonEmpty(json['backend']),
      network: _nonEmpty(json['network']),
      reason: _nonEmpty(json['reason']),
      directory: _nonEmpty(json['directory']),
      enabled: json['enabled'] as bool?,
      effectiveEnabled: json['effectiveEnabled'] as bool? ?? false,
      grants: _grants(json['grants']),
      allowHosts: _stringList(json['allowHosts']),
      updatedAt: json['updatedAt'] as int?,
      projects: rawProjects is List
          ? rawProjects
                .whereType<Map>()
                .map(SandboxProjectSummary.fromJson)
                .where((p) => p.directory.isNotEmpty)
                .toList()
          : const [],
      error: _nonEmpty(json['error']),
    );
  }

  final bool success;

  /// Whether the machine's own config asks for sandboxing.
  final bool machineEnabled;

  /// Whether boxy can actually sandbox here. False means sessions run
  /// unsandboxed whatever the policy says, so the UI has to say so rather
  /// than offer a switch with no effect.
  final bool available;

  final String? backend;

  /// The egress mode: `public`, `allowlist` or `none`.
  final String? network;

  /// Why sandboxing is unavailable, when it is.
  final String? reason;

  final String? directory;

  /// The project's explicit choice, or null when it follows the machine.
  final bool? enabled;

  /// What will actually happen for this project.
  final bool effectiveEnabled;

  final List<SandboxGrant> grants;
  final List<String> allowHosts;
  final int? updatedAt;

  /// Every configured project, for `sandbox-list`.
  final List<SandboxProjectSummary> projects;

  final String? error;
}

/// One configured project in a `sandbox-list` response.
class SandboxProjectSummary {
  const SandboxProjectSummary({
    required this.directory,
    this.enabled,
    this.effectiveEnabled = false,
    this.grants = const [],
    this.allowHosts = const [],
    this.updatedAt,
  });

  factory SandboxProjectSummary.fromJson(Map<dynamic, dynamic> json) =>
      SandboxProjectSummary(
        directory: json['directory'] as String? ?? '',
        enabled: json['enabled'] as bool?,
        effectiveEnabled: json['effectiveEnabled'] as bool? ?? false,
        grants: _grants(json['grants']),
        allowHosts: _stringList(json['allowHosts']),
        updatedAt: json['updatedAt'] as int?,
      );

  final String directory;
  final bool? enabled;
  final bool effectiveEnabled;
  final List<SandboxGrant> grants;
  final List<String> allowHosts;
  final int? updatedAt;
}

List<SandboxGrant> _grants(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(SandboxGrant.fromJson)
      .where((grant) => grant.path.isNotEmpty)
      .toList();
}

String? _nonEmpty(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
