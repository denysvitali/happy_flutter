import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/default_mcp_servers.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'new_session_form_group.dart';

/// Chooses which default MCP servers a new Kubernetes session starts with.
///
/// [selected] holds the enabled server ids; the dialog turns it into the
/// spawn request's `mcpServers` with [mcpServersForSpawn].
class KubernetesMcpSection extends StatelessWidget {
  const KubernetesMcpSection({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final allSelected = kDefaultMcpServerIds.every(selected.contains);
    final summary = allSelected
        ? l10n.newSessionMcpServersAll
        : selected.isEmpty
        ? l10n.newSessionMcpServersNone
        : [
            for (final id in kDefaultMcpServerIds)
              if (selected.contains(id)) _title(l10n, id),
          ].join(', ');

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        key: const Key('k8s-mcp-servers'),
        tilePadding: kNewSessionTilePadding,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.extension_outlined),
        title: Text(l10n.newSessionMcpServers),
        subtitle: Text(summary, style: AppText.secondary(theme)),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.newSessionMcpServersHint,
                style: AppText.secondary(theme),
              ),
            ),
          ),
          for (final id in kDefaultMcpServerIds)
            SwitchListTile(
              key: ValueKey('k8s-mcp-$id'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              value: selected.contains(id),
              title: Text(_title(l10n, id)),
              subtitle: Text(_hint(l10n, id)),
              onChanged: enabled
                  ? (value) {
                      final next = {...selected};
                      if (value) {
                        next.add(id);
                      } else {
                        next.remove(id);
                      }
                      onChanged(next);
                    }
                  : null,
            ),
        ],
      ),
    );
  }

  static String _title(AppLocalizations l10n, String id) => switch (id) {
    'github-actions' => l10n.newSessionMcpGithubActions,
    'loki' => l10n.newSessionMcpLoki,
    _ => id,
  };

  static String _hint(AppLocalizations l10n, String id) => switch (id) {
    'github-actions' => l10n.newSessionMcpGithubActionsHint,
    'loki' => l10n.newSessionMcpLokiHint,
    _ => '',
  };
}
