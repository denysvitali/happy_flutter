/// Coding agents whose installations can be managed by a machine daemon.
enum CodingAgent {
  codex('codex', 'Codex'),
  claude('claude', 'Claude Code');

  const CodingAgent(this.wireValue, this.displayName);

  final String wireValue;
  final String displayName;

  static CodingAgent? fromWire(String? value) {
    for (final agent in values) {
      if (agent.wireValue == value) return agent;
    }
    return null;
  }
}

/// Version and update state of one coding agent on a connected machine.
class ProviderVersion {
  const ProviderVersion({
    required this.provider,
    this.installed = false,
    this.version,
    this.latestVersion,
    this.updateAvailable = false,
    this.canUpdate = false,
    this.installMethod,
    this.error,
    this.updateStatus = 'idle',
    this.updateError,
    this.updateMessage,
  });

  factory ProviderVersion.fromJson(Map<String, dynamic> json) {
    final provider = CodingAgent.fromWire(json['provider'] as String?);
    if (provider == null) {
      throw const FormatException('Unknown coding agent');
    }
    return ProviderVersion(
      provider: provider,
      installed: json['installed'] == true,
      version: _nonEmpty(json['version']),
      latestVersion: _nonEmpty(json['latestVersion']),
      updateAvailable: json['updateAvailable'] == true,
      canUpdate: json['canUpdate'] == true,
      installMethod: _nonEmpty(json['installMethod']),
      error: _nonEmpty(json['error']),
      updateStatus: _nonEmpty(json['updateStatus']) ?? 'idle',
      updateError: _nonEmpty(json['updateError']),
      updateMessage: _nonEmpty(json['updateMessage']),
    );
  }

  final CodingAgent provider;
  final bool installed;
  final String? version;
  final String? latestVersion;
  final bool updateAvailable;
  final bool canUpdate;
  final String? installMethod;
  final String? error;
  final String updateStatus;
  final String? updateError;
  final String? updateMessage;

  bool get isUpdating => updateStatus == 'running';
}

class ProviderVersionsResponse {
  const ProviderVersionsResponse({
    required this.success,
    this.providers = const [],
    this.error,
  });

  factory ProviderVersionsResponse.fromJson(Map<String, dynamic> json) {
    final entries = json['providers'];
    return ProviderVersionsResponse(
      success: json['success'] == true,
      providers: entries is List
          ? List<ProviderVersion>.unmodifiable(
              entries
                  .whereType<Map<String, dynamic>>()
                  .where((entry) {
                    return CodingAgent.fromWire(entry['provider'] as String?) !=
                        null;
                  })
                  .map(ProviderVersion.fromJson),
            )
          : const [],
      error: _nonEmpty(json['error']),
    );
  }

  final bool success;
  final List<ProviderVersion> providers;
  final String? error;
}

class ProviderUpdateResponse {
  const ProviderUpdateResponse({
    required this.success,
    this.provider,
    this.error,
  });

  factory ProviderUpdateResponse.fromJson(Map<String, dynamic> json) {
    final entry = json['provider'];
    return ProviderUpdateResponse(
      success: json['success'] == true,
      provider:
          entry is Map<String, dynamic> &&
              CodingAgent.fromWire(entry['provider'] as String?) != null
          ? ProviderVersion.fromJson(entry)
          : null,
      error: _nonEmpty(json['error']),
    );
  }

  final bool success;
  final ProviderVersion? provider;
  final String? error;
}

String? _nonEmpty(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
