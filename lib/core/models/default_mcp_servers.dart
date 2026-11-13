/// The default MCP servers a Kubernetes session Pod can start with.
///
/// These are the servers the machine daemon injects into session Pods (names
/// match happy-cli-go's `internal/sessionmcp`), not the Claude Code MCP
/// configuration edited under Settings → MCP servers.
library;

/// Every selectable default server, in display order.
const kDefaultMcpServerIds = ['github-actions', 'loki'];

/// Whether Happy currently registers default MCP servers for this agent.
bool supportsDefaultMcpServers(String agent) =>
    agent == 'claude' || agent == 'codex';

/// The `mcpServers` value to send for [selected]: null (leave the choice to
/// the daemon, so servers added later are included) when every server is
/// selected, otherwise the sorted selection (possibly empty, meaning none).
List<String>? mcpServersForSpawn(Set<String> selected) {
  final known = kDefaultMcpServerIds;
  if (known.every(selected.contains)) return null;
  return [
    for (final id in known)
      if (selected.contains(id)) id,
  ];
}
