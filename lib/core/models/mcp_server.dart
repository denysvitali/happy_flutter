/// Models for the Claude Code MCP server configuration exposed by a machine
/// daemon over the `mcp-list` / `mcp-set` / `mcp-remove` / `mcp-toggle` RPCs.
///
/// The daemon parses several Claude Code files and reports each declaration
/// with the scope it came from. Scope decides which file an edit lands in, so
/// it is part of the identity of a server alongside its name.
library;

/// Which Claude Code file a server declaration lives in.
///
/// Ordered from highest to lowest resolution priority — a duplicate name in a
/// lower-priority scope is shadowed and never loaded by Claude Code.
enum McpServerScope {
  /// `<project>/.claude/settings.local.json`
  localSettings('localSettings'),

  /// `~/.claude.json` -> `projects[dir].mcpServers` (private to this project)
  local('local'),

  /// `<project>/.claude/settings.json`
  projectSettings('projectSettings'),

  /// `<project>/.mcp.json` (checked in, shared, requires approval)
  project('project'),

  /// `~/.claude/settings.json`
  userSettings('userSettings'),

  /// `~/.claude.json` -> `mcpServers` (available in every project)
  user('user');

  const McpServerScope(this.wire);

  /// The value used on the RPC wire.
  final String wire;

  /// Whether this scope only exists in the context of a project directory.
  bool get isProjectScoped =>
      this == McpServerScope.local ||
      this == McpServerScope.project ||
      this == McpServerScope.projectSettings ||
      this == McpServerScope.localSettings;

  static McpServerScope? fromWire(String? value) {
    for (final scope in McpServerScope.values) {
      if (scope.wire == value) return scope;
    }
    return null;
  }
}

/// How Claude Code talks to the server process.
enum McpTransport {
  stdio('stdio'),
  sse('sse'),
  http('http');

  const McpTransport(this.wire);

  final String wire;

  static McpTransport fromWire(String? value) {
    for (final transport in McpTransport.values) {
      if (transport.wire == value) return transport;
    }
    return McpTransport.stdio;
  }
}

/// One MCP server declaration on a machine.
class McpServer {
  const McpServer({
    required this.name,
    required this.scope,
    required this.transport,
    this.projectDir,
    this.command,
    this.args = const [],
    this.env = const {},
    this.url,
    this.headers = const {},
    this.enabled = true,
    this.disabled = false,
    this.disabledReason,
    this.sourcePath,
    this.needsAuth = false,
    this.shadowed = false,
    this.shadowedBy,
  });

  factory McpServer.fromJson(Map<dynamic, dynamic> json) => McpServer(
    name: json['name'] as String? ?? '',
    scope:
        McpServerScope.fromWire(json['scope'] as String?) ??
        McpServerScope.user,
    projectDir: _nonEmpty(json['projectDir']),
    transport: McpTransport.fromWire(json['transport'] as String?),
    command: _nonEmpty(json['command']),
    args: _stringList(json['args']),
    env: _stringMap(json['env']),
    url: _nonEmpty(json['url']),
    headers: _stringMap(json['headers']),
    enabled: json['enabled'] as bool? ?? false,
    disabled: json['disabled'] as bool? ?? false,
    disabledReason: _nonEmpty(json['disabledReason']),
    sourcePath: _nonEmpty(json['sourcePath']),
    needsAuth: json['needsAuth'] as bool? ?? false,
    shadowed: json['shadowed'] as bool? ?? false,
    shadowedBy: McpServerScope.fromWire(json['shadowedBy'] as String?),
  );

  final String name;
  final McpServerScope scope;
  final String? projectDir;
  final McpTransport transport;
  final String? command;
  final List<String> args;
  final Map<String, String> env;
  final String? url;
  final Map<String, String> headers;

  /// Effective state: whether Claude Code will load this server.
  final bool enabled;

  /// True only when the user turned it off, as opposed to a project server
  /// that has never been approved.
  final bool disabled;

  /// `user`, `sidecar`, or `awaiting-approval`.
  final String? disabledReason;
  final String? sourcePath;
  final bool needsAuth;
  final bool shadowed;
  final McpServerScope? shadowedBy;

  /// A `.mcp.json` server the user has neither approved nor rejected.
  bool get awaitingApproval => disabledReason == 'awaiting-approval';

  /// What the server points at — a command line or a URL.
  String get target {
    if (transport == McpTransport.stdio) {
      final parts = [?command, ...args];
      return parts.join(' ');
    }
    return url ?? '';
  }

  /// Identity used for list keys and edit round-trips: a name is only unique
  /// within a scope (and, for project scopes, within a directory).
  String get identity => '${scope.wire}:${projectDir ?? ''}:$name';

  McpServer copyWith({
    String? name,
    McpServerScope? scope,
    String? projectDir,
    McpTransport? transport,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    String? url,
    Map<String, String>? headers,
    bool? enabled,
  }) => McpServer(
    name: name ?? this.name,
    scope: scope ?? this.scope,
    projectDir: projectDir ?? this.projectDir,
    transport: transport ?? this.transport,
    command: command ?? this.command,
    args: args ?? this.args,
    env: env ?? this.env,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    enabled: enabled ?? this.enabled,
    disabled: disabled,
    disabledReason: disabledReason,
    sourcePath: sourcePath,
    needsAuth: needsAuth,
    shadowed: shadowed,
    shadowedBy: shadowedBy,
  );
}

/// Response for every MCP RPC. Mutations return the fresh snapshot so the app
/// never has to follow a write with a read.
class McpConfigResponse {
  const McpConfigResponse({
    required this.success,
    this.servers = const [],
    this.projects = const [],
    this.projectDir,
    this.claudeConfigPath,
    this.userSettingsPath,
    this.projectMcpPath,
    this.enableAllProjectMcpServers = false,
    this.warnings = const [],
    this.error,
  });

  factory McpConfigResponse.fromJson(Map<String, dynamic> json) {
    final rawServers = json['servers'];
    return McpConfigResponse(
      success: json['success'] as bool? ?? false,
      error: _nonEmpty(json['error']),
      servers: rawServers is List
          ? rawServers
                .whereType<Map>()
                .map(McpServer.fromJson)
                .where((server) => server.name.isNotEmpty)
                .toList()
          : const [],
      projects: _stringList(json['projects']),
      projectDir: _nonEmpty(json['projectDir']),
      claudeConfigPath: _nonEmpty(json['claudeConfigPath']),
      userSettingsPath: _nonEmpty(json['userSettingsPath']),
      projectMcpPath: _nonEmpty(json['projectMcpPath']),
      enableAllProjectMcpServers:
          json['enableAllProjectMcpServers'] as bool? ?? false,
      warnings: _stringList(json['warnings']),
    );
  }

  final bool success;
  final List<McpServer> servers;
  final List<String> projects;
  final String? projectDir;
  final String? claudeConfigPath;
  final String? userSettingsPath;
  final String? projectMcpPath;
  final bool enableAllProjectMcpServers;
  final List<String> warnings;
  final String? error;
}

String? _nonEmpty(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  final out = <String, String>{};
  value.forEach((key, item) {
    if (key is String && item is String) out[key] = item;
  });
  return out;
}
