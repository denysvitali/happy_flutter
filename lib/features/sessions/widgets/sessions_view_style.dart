import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';

/// Layouts the sessions tab can render, keyed by their persisted
/// `sessionsViewStyle` setting value.
enum SessionsViewStyle {
  missionControl('mission_control', Icons.space_dashboard_outlined),
  statusBoard('status', Icons.view_agenda_outlined),
  machines('machines', Icons.dns_outlined),
  folder('folder', Icons.folder_outlined),
  repository('repository', Icons.source_outlined),
  unreadFocus('unread_focus', Icons.mark_chat_unread_outlined);

  const SessionsViewStyle(this.wire, this.icon);

  /// Persisted setting value.
  final String wire;
  final IconData icon;

  /// Workspace grouping for folder-style layouts; null for other layouts.
  SessionGrouping? get workspaceGrouping => switch (this) {
    folder => SessionGrouping.folder,
    repository => SessionGrouping.repository,
    _ => null,
  };

  /// Unknown values fall back to Mission Control, the setting default.
  static SessionsViewStyle fromWire(String value) {
    for (final style in values) {
      if (style.wire == value) return style;
    }
    return missionControl;
  }

  String label(AppLocalizations l10n) => switch (this) {
    missionControl => l10n.sessionsViewStyleMissionControl,
    statusBoard => l10n.sessionsViewStyleStatusBoard,
    machines => l10n.sessionsViewStyleMachines,
    folder => l10n.sessionsViewStyleFolderCentric,
    repository => l10n.sessionsViewStyleRepository,
    unreadFocus => l10n.sessionsViewStyleUnreadFocus,
  };

  String description(AppLocalizations l10n) => switch (this) {
    missionControl => l10n.sessionsViewStyleMissionControlHint,
    statusBoard => l10n.sessionsViewStyleStatusBoardHint,
    machines => l10n.sessionsViewStyleMachinesHint,
    folder => l10n.sessionsViewStyleFolderCentricHint,
    repository => l10n.sessionsViewStyleRepositoryHint,
    unreadFocus => l10n.sessionsViewStyleUnreadFocusHint,
  };
}

/// App-bar control that switches the sessions layout in one tap.
///
/// The icon mirrors the current layout so the active mode stays visible
/// without opening Settings.
class SessionsViewStyleButton extends ConsumerWidget {
  const SessionsViewStyleButton({
    super.key,
    this.showLabel = false,
    this.asTitle = false,
  });

  final bool showLabel;
  final bool asTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = SessionsViewStyle.fromWire(
      ref.watch(settingsNotifierProvider.select((s) => s.sessionsViewStyle)),
    );
    final cs = Theme.of(context).colorScheme;
    final hasLabel = showLabel || asTitle;
    final color = asTitle ? cs.onSurface : cs.primary;
    final menu = PopupMenuButton<SessionsViewStyle>(
      icon: hasLabel ? null : Icon(current.icon),
      child: hasLabel
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!asTitle) ...[
                    Icon(current.icon, size: AppIconSize.md, color: color),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      asTitle ? l10n.sessionHistoryTitle : current.label(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: asTitle
                          ? AppText.screenTitle(Theme.of(context))
                          : AppText.label(Theme.of(context), color),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.expand_more, size: AppIconSize.md, color: color),
                ],
              ),
            )
          : null,
      tooltip: '${l10n.sessionsViewStyleTooltip}: ${current.label(l10n)}',
      initialValue: current,
      onSelected: (style) {
        if (style == current) return;
        unawaited(
          ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('sessionsViewStyle', style.wire),
        );
      },
      itemBuilder: (context) => [
        for (final style in SessionsViewStyle.values)
          PopupMenuItem<SessionsViewStyle>(
            value: style,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                style.icon,
                color: style == current ? cs.primary : null,
              ),
              title: Text(style.label(l10n)),
              subtitle: Text(style.description(l10n)),
              trailing: style == current
                  ? Icon(Icons.check, color: cs.primary)
                  : null,
            ),
          ),
      ],
    );
    return asTitle
        ? Semantics(container: true, button: true, child: menu)
        : menu;
  }
}
