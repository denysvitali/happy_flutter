import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';

/// Layouts the sessions tab can render, keyed by their persisted
/// `sessionsViewStyle` setting value.
enum SessionsViewStyle {
  missionControl('mission_control', Icons.space_dashboard_outlined),
  statusBoard('status', Icons.view_agenda_outlined),
  machines('machines', Icons.dns_outlined),
  folder('folder', Icons.folder_outlined),
  unreadFocus('unread_focus', Icons.mark_chat_unread_outlined);

  const SessionsViewStyle(this.wire, this.icon);

  /// Persisted setting value.
  final String wire;
  final IconData icon;

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
    unreadFocus => l10n.sessionsViewStyleUnreadFocus,
  };

  String description(AppLocalizations l10n) => switch (this) {
    missionControl => l10n.sessionsViewStyleMissionControlHint,
    statusBoard => l10n.sessionsViewStyleStatusBoardHint,
    machines => l10n.sessionsViewStyleMachinesHint,
    folder => l10n.sessionsViewStyleFolderCentricHint,
    unreadFocus => l10n.sessionsViewStyleUnreadFocusHint,
  };
}

/// App-bar control that switches the sessions layout in one tap.
///
/// The icon mirrors the current layout so the active mode stays visible
/// without opening Settings.
class SessionsViewStyleButton extends ConsumerWidget {
  const SessionsViewStyleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = SessionsViewStyle.fromWire(
      ref.watch(settingsNotifierProvider.select((s) => s.sessionsViewStyle)),
    );
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<SessionsViewStyle>(
      icon: Icon(current.icon),
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
  }
}
